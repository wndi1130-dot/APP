"""S1a 밸런스 확인용 시뮬레이터 (설계 도구, 게임 코드가 아니다).

docs/design/briefs/s1a_politics_numbers.md의 수치로 24구간 판을 자동으로 돌린다.
플레이어는 단순한 규칙으로 움직이는 정책 셋이다.

  passive    레버를 그대로 두고, 요구를 거절하고, 거래하지 않는다.
  caretaker  처지를 견딜 선 안으로 돌보고, 감당할 수 있는 요구는 들어주고, 공개 협상으로 법을 통과시킨다.
  nodeal     caretaker와 같지만 의회에서 거래하지 않는다.

  schemer    caretaker에 협박을 더한다. 공개 협상으로 모자라면 비밀로 큰 집단부터 협박한다.
  idealist   caretaker처럼 거래하되, 의회가 가장 좋아하는 법(대개 이상 법)부터 올린다.

넣지 않은 것: AI 지도자의 뇌물·협박, 사적 부탁, 세력, 결과 아크, 사건 카드의 개별 선택(생존자 데려오기만 넣었다),
비밀 투표와 비상대권의 효과, 비밀.
사용: python3 docs/design/sim/s1a_balance.py [판 수] [--tune key=value ...]
"""
import json
import math
import random
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]

# ---- 브리프 수치 (조정은 여기서). 시뮬레이션 뒤 고친 값: haul_total 20→32→36(법 개정 뒤), engine_fatigue, natural_ceiling, engine_exposure0 35→45, strike_rel −40→−15, refuse_rel ----
P = dict(
    segments=24, session_every=3,
    coal0=100, food0=100, med0=20, lux0=8, trust0=50, tension0=20,
    coal_run=6, coal_stop=2, coal_heat_per_lever=0.25, food_per_person_lever=0.025,
    haul_total=36, target_boost=3.0, lever_step=12, winter_every=6, winter_drop=5,
    injury_rate=0.25, death_rate=0.03, med_per_injured=0.5,
    recover_base=1, recover_cap=3, target_keep=0.85,
    engine_fatigue=2.0, shift_relief=10, shift_coal=3,
    natural_ceiling=15, engine_exposure0=45, strike_rel=-15, refuse_rel=5,
    rescue_rate=0.2, crisis_line=30, forced_agenda=1, plan_line=120, thrown_horde=0.05, store_risk=0.03, lever_line=50,
    repeal=1, repeal_cool=2, repeal_rel=10, hostile_grudge=2, blackmail_reputation=3, grudge_decay=2, blackmail_pull=1,
)
COMMS = ['tail', 'engine', 'guard', 'medtech', 'front']
POP = dict(tail=90, engine=25, guard=25, medtech=30, front=30)
START = dict(  # 온기, 배급, 과밀, 노출
    tail=(35, 40, 75, 60), engine=(80, 55, 40, 35), guard=(55, 55, 45, 55),
    medtech=(55, 50, 45, 25), front=(75, 65, 20, 10))
REL0 = dict(tail=-20, engine=10, guard=15, medtech=5, front=20)
COH0 = dict(tail=0.55, engine=0.85, guard=0.80, medtech=0.70, front=0.65)
# 이념: 배급(+1 균등/-1 기여), 권위(+1 규율/-1 실용), 기술(+1 복원/-1 적응)
IDEO = dict(tail=(1, -1, -1), engine=(-1, 1, 1), guard=(-1, 1, 0), medtech=(0, -1, 1), front=(-1, -1, 1))
OPPOSITE = dict(tail='front', front='tail', engine='medtech', medtech='engine', guard='tail')

# 법 (2026-10-07 개정). 프로스트펑크식: 모두에게 좋은 법은 자원이 많이 들고, 살리는 법은 다수가 싫어한다.
# kind 일반/통치, axes (배급, 권위, 기술), mats 처지 변화 (온기, 배급, 과밀, 노출), rels 통과 때 관계 변화,
# like 처지 밖의 선호(입장 점수에 더함), res 자원 효과, crisis 위기 때 강제 안건이 되는 자원, open 열림 조건
def d(**kw):
    return kw
def law(kind, axes, open_=lambda s: True, mats=None, rels=None, like=None, res=None, crisis=()):
    return dict(kind=kind, axes=axes, open=open_, mats=mats or {}, rels=rels or {}, like=like or {},
                res=res or {}, crisis=crisis)
ALL = lambda v: {c: v for c in COMMS}
LAWS = {
    # 식량: 다 같이 먹을까, 일한 만큼 먹을까, 내일 심을 씨앗을 오늘 먹을까
    # 이상 법은 레버의 바닥을 법으로 묶는다. 위기에도 못 깎으니 비싸다
    'common_kitchen': law('normal', (1, 0, 0), like=d(tail=2, medtech=1, guard=1, engine=1), rels=d(tail=10),
                          res=d(ration_floor=3, tension_add=-1)),
    # 가혹한 법은 피해자가 저마다 다르다. 다 꼬리칸에 몰면 45석이 사지지 않는다(12장)
    'contribution_ration': law('normal', (-1, 0, 0), mats=d(engine=(0, 10, 0, 0), guard=(0, 10, 0, 0),
                               tail=(0, -5, 0, 0), front=(0, -10, 0, 0), medtech=(0, -5, 0, 0)), res=d(food_add=-1.5),
                               crisis=('food',)),
    'seed_grain': law('normal', (0, -1, -1), lambda s: s.food <= 50, rels=d(front=-20, engine=-5, medtech=-5),
                      like=d(tail=1), res=d(food_once=30), crisis=('food',)),
    # 추위: 꼬리칸까지 데울까, 석탄을 나눠 줄까, 꼬리칸이 눈을 녹여 물을 댈까
    'common_heating': law('normal', (1, 0, -1), lambda s: s.m['tail'][0] <= 40,
                          like=d(tail=2, medtech=1), rels=d(tail=10), res=d(heat_floor=3, tension_add=-1)),
    'heat_quota': law('normal', (-1, 1, 0), lambda s: s.coal <= 50,
                      mats=d(tail=(-10, 0, 0, 0), medtech=(-10, 0, 0, 0), guard=(-5, 0, 0, 0)), res=d(heat_mult=0.5),
                      crisis=('coal',)),
    'snow_duty': law('normal', (1, 1, -1), mats=d(tail=(-5, 0, 0, 5), front=(-5, 0, 0, 15), medtech=(-5, 0, 0, 5)),
                     res=d(coal_add=-1.0), crisis=('coal',)),
    # 노동
    'child_labor': law('normal', (-1, -1, 0), lambda s: s.coal <= 40 or s.food <= 40,
                       mats=d(tail=(0, 0, 0, 10)), rels=d(tail=-5, medtech=-10), res=d(haul_mult=1.2, fear_once=5),
                       crisis=('coal', 'food')),
    'corpse_throw': law('normal', (0, -1, -1), lambda s: s.corpse_issue, res=d(corpse='throw'), crisis=('corpse',)),
    'corpse_store': law('normal', (1, 0, 1), lambda s: s.corpse_issue, like=d(tail=1, medtech=1, front=1),
                        res=d(corpse='store'), crisis=('corpse',)),
    'corpse_burn': law('normal', (0, 1, 1), lambda s: s.corpse_issue, rels=d(medtech=-5, front=-5), like=d(engine=2),
                       res=d(corpse='burn'), crisis=('corpse',)),
    # 의료와 감염
    'treat_all': law('normal', (1, 0, 1), like=ALL(1), res=d(med_mult=1.6, heal=0.7)),
    'triage': law('normal', (0, -1, -1), lambda s: s.med <= 5 or s.injured >= 6,
                  rels=d(medtech=-15, tail=-5), res=d(med_mult=0.6, trust_once=-5), crisis=('med',)),
    'no_outsiders': law('normal', (0, 1, -1), lambda s: s.m['tail'][2] >= 75,
                        rels=d(medtech=-10, tail=-10), res=d(no_rescue=1, trust_once=-5)),
    # 질서와 통치
    'patrol': law('normal', (0, 1, 0), lambda s: s.tension >= 40, rels=d(tail=-5),
                  res=d(tension_add=-1, fear_add=2, food_add=0.5, death_mult=0.8)),
    'secret_ballot': law('normal', (0, -1, 0)),
    'emergency_powers': law('rule', (0, 1, 0), lambda s: s.tension >= 50 or s.trust <= 10),
    'strike_ban': law('rule', (0, 1, 0), lambda s: s.strikes > 0, rels=d(engine=-30)),
    'guided_voting': law('rule', (0, 1, 0), lambda s: s.session >= 3),
}
CORPSE = ['corpse_throw', 'corpse_store', 'corpse_burn']
IDEAL = ['common_kitchen', 'common_heating', 'corpse_store', 'treat_all']
HARSH = ['contribution_ration', 'seed_grain', 'heat_quota', 'snow_duty', 'child_labor', 'triage', 'no_outsiders',
         'corpse_burn']
SEATS = dict(tail=45, front=15, medtech=15, engine=13, guard=12)  # allocateSeats 결과(브리프 0.1)


def load_places():
    data = json.loads((ROOT / 'ref/places_loot_draft.json').read_text(encoding='utf-8'))
    return [(p['id'], p['risk'], p['loot']) for p in data['places']]


def band(rel):  # 7단계 → 관계 점수
    if rel >= 70: return 2
    if rel >= 15: return 1
    if rel > -15: return 0
    if rel > -70: return -1
    return -2


def clamp(x, lo, hi):
    return max(lo, min(hi, x))


class Run:
    def __init__(self, seed, policy, places):
        self.r = random.Random(seed)
        self.policy = policy
        self.places = places
        self.coal, self.food, self.med, self.lux = P['coal0'], P['food0'], P['med0'], P['lux0']
        self.trust, self.tension, self.fear = P['trust0'], P['tension0'], 0.0
        self.base = {c: list(START[c]) for c in COMMS}       # 레버 2 기준 처지
        self.base['engine'][3] = P['engine_exposure0']
        self.random_laws = policy.endswith('_random')
        self.policy = policy.replace('_random', '')
        self.heat = {c: 2 for c in COMMS}
        self.ration = {c: 2 for c in COMMS}
        self.rel = dict(REL0)
        self.fervor = {c: 0 for c in COMMS}
        self.bad_streak = {c: 0 for c in COMMS}
        self.pop = dict(POP)
        self.injured = 0
        self.passed = set()
        self.promises = []  # (공동체, 마감 구간, 종류)
        self.seg = 0
        self.session = 0
        self.strikes = 0
        self.strike_warned = False
        self.lost_segments = 0
        self.trust_crisis = None
        self.tension_crisis_used = 0
        self.stats = Counter()
        self.end = None
        self.demand_cool = {c: 0 for c in COMMS}
        self.grudge = {c: 0 for c in COMMS}      # 적의: 열차장 개인에 대한 원한(0~3). 처지와 따로 간다
        self.last_offense = {c: 0 for c in COMMS}
        self.passed_at = {}                         # 법 → 통과한 회기
        self.secrets, self.blackmails = 1, 0
        self.leashes = []  # 협박의 목줄(3.4): [공동체, 시작 구간]
        self.repealed_at = {}                       # 법 → 폐지한 회기
        self.bought_by = {}                         # 법 → (약속한 공동체들, 회기)
        self.corpse_issue = False  # 첫 죽음이 시신 처리 안건을 연다
        self.thrown = 0            # 밖으로 던진 시신: 선로를 따라오는 무리에 섞인다(아는 얼굴)
        self.stored = 0            # 냉동칸에 둔 시신

    # 처지 = 기준 + 레버 차이
    @property
    def m(self):
        out = {}
        for c in COMMS:
            w, ra, cr, ex = self.base[c]
            out[c] = (clamp(w + P['lever_step'] * (self.heat[c] - 2), 0, 100),
                      clamp(ra + P['lever_step'] * (self.ration[c] - 2), 0, 100),
                      clamp(cr, 0, 100), clamp(ex, 0, 100))
        return out

    def res(self, key, default=0.0):
        """통과한 법들의 자원 효과를 모은다. *_mult는 곱하고 나머지는 더한다."""
        mult = key.endswith('_mult') or key == 'heal'
        out = 1.0 if mult else default
        for l in self.passed:
            v = LAWS[l]['res'].get(key)
            if v is None or isinstance(v, str):
                continue
            if key == 'heal':
                out = max(out, v)
            elif mult:
                out *= v
            else:
                out += v
        return out if not (key == 'heal' and out == 1.0) else default

    @property
    def corpse(self):
        for l in CORPSE:
            if l in self.passed:
                return LAWS[l]['res']['corpse']
        return None

    def on_death(self, n, c='tail'):
        """죽은 사람은 일어난다. 시신 처리 법이 대가를 정한다."""
        if n <= 0:
            return
        self.pop[c] -= n
        self.stats['deaths'] += n
        way = self.corpse
        if way is None:
            self.corpse_issue = True
            self.tension += 3 * n  # 누가 어떻게 치울지 다툰다. 일단 밖으로 던진다
            self.thrown += n
        elif way == 'throw':
            self.thrown += n
        elif way == 'store':
            self.stored += n
            self.base['tail'][2] += 1 * n
        elif way == 'burn':
            self.coal += 2 * n
            self.rel['tail'] = clamp(self.rel['tail'] - 3 * n, -100, 100)

    def apply_law(self, law):
        L = LAWS[law]
        for c, delta in L['mats'].items():
            for i in range(4):
                self.base[c][i] += delta[i]
        for c, dr in L['rels'].items():
            self.rel[c] = clamp(self.rel[c] + dr, -100, 100)
        r = L['res']
        self.trust += r.get('trust_once', 0)
        self.fear += r.get('fear_once', 0)
        self.food += r.get('food_once', 0)
        self.lux += r.get('lux_once', 0)
        if r.get('engine_calm'):
            self.fervor['engine'] = max(0, self.fervor['engine'] - 1)
        if law == 'guided_voting':
            self.stats['guided_left'] = 3
        if law in CORPSE:
            self.corpse_issue = False

    # ---- 구간 진행 ----
    def step(self):
        self.seg += 1
        if self.seg % P['winter_every'] == 0:
            for c in COMMS:
                self.base[c][0] -= P['winter_drop']
        self.policy_levers()
        striking = self.fervor['engine'] >= 1 and self.rel['engine'] <= P['strike_rel'] and 'strike_ban' not in self.passed
        if striking:
            self.strikes += 1 if not self.stats['in_strike'] else 0
            self.stats['in_strike'] = 1
            self.lost_segments += 1
            self.tension += 3
        else:
            self.stats['in_strike'] = 0
        base_heat = self.heat_cost()
        heat_coal = base_heat * self.res('heat_mult') + self.res('coal_add')
        food_use = sum(self.pop[c] * self.ration[c] for c in COMMS) * P['food_per_person_lever']
        food_use = food_use * self.res('food_mult') + self.res('food_add')
        self.stats['law_coal'] += heat_coal - base_heat
        self.stats['law_food'] += food_use - sum(self.pop[c] * self.ration[c] for c in COMMS) * P['food_per_person_lever']
        self.coal -= heat_coal + (4 if striking else P['coal_run'])
        self.food -= food_use
        if not striking:
            self.base['engine'][3] += P['engine_fatigue']  # 화부 노동이 쌓인다
            self.stop()
        self.medicine_tick()
        self.drift()
        self.demands()
        if self.seg % P['session_every'] == 0:
            self.council()
        self.promise_tick()
        self.leash_tick()
        self.meters()
        self.check_end()

    def heat_cost(self):
        # 난방은 사람 수만큼 칸이 많다. 40명을 한 칸으로 친다(200명, 레버 2 → 2.5)
        return sum(self.heat[c] * self.pop[c] / 40 for c in COMMS) * P['coal_heat_per_lever']

    def stop(self):
        pid, risk, loot = self.r.choice(self.places)
        target = self.policy_target(pid, loot)
        if target is None:
            self.stats['passed_stops'] += 1
            return
        self.coal -= P['coal_stop']
        weights = {k: v * (P['target_boost'] if k == target else 1) for k, v in loot.items()}
        tot = sum(weights.values())
        haul = P['haul_total'] * self.r.uniform(0.7, 1.3)
        if self.fervor['tail'] >= 1 and self.rel['tail'] <= -40:
            haul *= 0.7  # 꼬리칸 작업 거부
        haul *= self.res('haul_mult')
        for k, w in weights.items():
            amt = haul * w / tot
            if k == 'coal': self.coal += amt
            elif k == 'food': self.food += amt
            elif k == 'medicine': self.med += amt
            elif k == 'luxury': self.lux += amt / 3
            elif self.r.random() < amt / 10: self.stats['got_' + k] += 1
        guard_mult = 1.5 if (self.fervor['guard'] >= 1 and self.rel['guard'] <= -40) else 1
        horde = min(1.5, 1 + P['thrown_horde'] * self.thrown)  # 던진 시신이 무리를 키운다
        lam = risk * P['injury_rate'] * guard_mult * horde
        inj = sum(1 for _ in range(6) if self.r.random() < lam / 6)
        self.injured += inj
        if self.r.random() < risk * P['death_rate'] * guard_mult * horde * self.res('death_mult'):
            self.on_death(1)
        self.stats['target_' + target] += 1
        # 구조 카드(ev_field_wounded): 생존자를 데려오면 꼬리칸 사람·과밀·부상자가 는다
        if self.r.random() < P['rescue_rate']:
            if self.res('no_rescue'):
                self.trust -= 1; self.stats['rescue_refused'] += 1
            elif self.policy != 'passive' and self.m['tail'][2] >= 80:
                self.trust -= 1; self.rel['medtech'] -= 3; self.stats['rescue_declined'] += 1  # 카드에서 두고 온다
            else:
                self.pop['tail'] += 2; self.base['tail'][2] += 3; self.injured += 1
                self.stats['rescued'] += 1

    def medicine_tick(self):
        need = self.injured * P['med_per_injured'] * self.res('med_mult')
        if self.med >= need:
            self.med -= need
            heal = self.res('heal', 0.4)
            healed = sum(1 for _ in range(self.injured) if self.r.random() < heal)
            self.injured -= healed
        else:
            self.med = 0
            dead = sum(1 for _ in range(self.injured) if self.r.random() < 0.1)
            self.injured -= dead
            self.on_death(dead)
        # 냉동칸: 안치한 시신이 많을수록 녹아 일어나는 사고가 난다
        if self.stored and self.r.random() < min(0.3, P['store_risk'] * self.stored):
            self.injured += 2; self.tension += 8; self.stored = 0
            self.stats['cold_car_outbreak'] += 1

    def drift(self):
        m = self.m
        for c in COMMS:
            w, ra, cr, ex = m[c]
            dr = 0
            dr -= max(0, 45 - w) / 10
            dr -= max(0, 45 - ra) / 10
            dr -= max(0, cr - 60) / 15
            dr -= max(0, ex - 50) / 15
            if dr == 0:
                # 넷 모두 견딜 선 안: 기본 +1에 여유분을 더한다(최대 recover_cap)
                surplus = max(0, w - 45) + max(0, ra - 45) + max(0, 60 - cr) + max(0, 50 - ex)
                dr = min(P['recover_cap'], P['recover_base'] + surplus / 30)
                # 처지가 좋아도 저절로는 natural_ceiling까지만 오른다. 그 위는 거래와 약속으로
                dr = max(0, min(dr, P['natural_ceiling'] - self.rel[c]))
            if self.food <= 0:
                dr -= 5
            self.rel[c] = clamp(self.rel[c] + clamp(dr, -6, P['recover_cap']), -100, 100)
            # 열기
            if self.rel[c] <= -40:
                self.bad_streak[c] += 1
                if self.bad_streak[c] >= 3:
                    self.fervor[c] = min(3, self.fervor[c] + 1)
                    self.bad_streak[c] = 0
            else:
                self.bad_streak[c] = 0
            if self.rel[c] >= 15 and self.fervor[c] > 0:
                self.fervor[c] -= 1

    def demands(self):
        m = self.m
        for c in COMMS:
            if self.demand_cool[c] > 0:
                self.demand_cool[c] -= 1
                continue
            w, ra, _, ex = m[c]
            if c == 'engine' and ex > 50:
                # 기관실의 요구: 화부 교대
                self.demand_cool[c] = 2
                self.stats['demands'] += 1
                if self.policy != 'passive' and self.coal > 40:
                    self.base['engine'][3] -= P['shift_relief']; self.coal -= P['shift_coal']
                    self.stats['demands_met'] += 1; self.stats['shift_relief'] += 1
                else:
                    self.fervor[c] = min(3, self.fervor[c] + 1)
                    self.rel[c] -= P['refuse_rel']
                    self.stats['demands_refused'] += 1
                continue
            if w >= 45 and ra >= 45:
                continue
            self.demand_cool[c] = 2
            self.stats['demands'] += 1
            lever = self.heat if w < ra else self.ration
            if self.policy != 'passive' and lever[c] < 4 and self.coal > 40 and self.food > 40:
                lever[c] += 1
                self.stats['demands_met'] += 1
            else:
                self.fervor[c] = min(3, self.fervor[c] + 1)
                self.rel[c] -= P['refuse_rel']
                self.stats['demands_refused'] += 1
        # 기관실 파업 경고와 대응
        if self.fervor['engine'] >= 1 and self.rel['engine'] <= -15:
            self.strike_warned = True
        if self.policy != 'passive' and self.fervor['engine'] >= 1 and self.rel['engine'] <= P['strike_rel']:
            if self.food > 20:
                self.ration['engine'] = min(4, self.ration['engine'] + 1)
                self.fervor['engine'] -= 1
                self.fervor[OPPOSITE['engine']] = min(3, self.fervor[OPPOSITE['engine']] + 1)
                self.rel['engine'] += 10
                self.stats['strike_conceded'] += 1

    # ---- 의회 ----
    def stance(self, c, law, repeal=False, grudge=True):
        L = LAWS[law]
        axes, mats, rels = L['axes'], L['mats'], L['rels']
        mat = L['like'].get(c, 0)
        if c in mats:
            dw, dr, dc, de = mats[c]
            gain = dw + dr - dc - de
            mat += 2 if gain >= 15 else 1 if gain >= 5 else -2 if gain <= -15 else -1 if gain <= -5 else 0
        if c in rels:
            mat += -2 if rels[c] <= -15 else -1
        ide = sum(a * b for a, b in zip(axes, IDEO[c]))
        if repeal:  # 폐지는 그 법의 반대 방향으로 셈한다. 열차장과의 관계는 그대로
            mat, ide = -mat, -ide
        score = mat + ide + band(self.rel[c])
        if grudge and self.grudge[c] >= P['hostile_grudge']:
            score = min(score, -3)  # 적대 표: 사상이 같아도 열차장의 안건엔 반대한다
        elif grudge and self.grudge[c] >= 1:
            score -= 1
        return score, ide

    def split(self, score):
        if score >= 3: return 0.8, 0.2, 0.0
        if score >= 1: return 0.4, 0.5, 0.1
        if score == 0: return 0.1, 0.8, 0.1
        if score >= -2: return 0.1, 0.5, 0.4
        return 0.0, 0.2, 0.8

    def blocs(self, law, repeal=False):
        out = {}
        for c in COMMS:
            score, ide = self.stance(c, law, repeal)
            y, u, n = self.split(score)
            s = SEATS[c]
            yes = round(s * y); no = round(s * n); und = s - yes - no
            out[c] = dict(yes=yes, und=und, no=no, score=score, ide=ide)
        return out

    def expected(self, blocs):
        return sum(b['yes'] + b['und'] * clamp(0.5 + 0.1 * b['score'], 0.2, 0.8) for b in blocs.values())

    def council(self):
        self.session += 1
        if self.session % 2 == 0: self.secrets += 1  # 밀고·필드 문서에서 비밀이 온다(대략)
        for c in COMMS:  # 적의는 새 잘못 없이 2회기가 지나면 하나 준다
            if self.grudge[c] and self.session - self.last_offense[c] >= P['grudge_decay']:
                self.grudge[c] -= 1; self.last_offense[c] = self.session
        self.stats['hostile_blocs'] += sum(1 for c in COMMS if self.grudge[c] >= P['hostile_grudge'])
        cool = P['repeal_cool']
        options = [(l, False) for l, v in LAWS.items() if l not in self.passed and v['open'](self)
                   and not (l in CORPSE and self.corpse) and self.session - self.repealed_at.get(l, -99) > cool]
        if P['repeal'] and self.policy not in ('passive', 'idealist'):
            options += [(l, True) for l in self.passed if self.session - self.passed_at[l] >= cool]
        if not options:
            return
        crisis = [k for k, lim in (('coal', P['crisis_line']), ('food', P['crisis_line'])) if getattr(self, k) < lim]
        if self.corpse_issue: crisis.append('corpse')
        if self.med <= 3 and self.injured >= 4: crisis.append('med')
        forced = [o for o in options if (set(LAWS[o[0]]['crisis']) & set(crisis) if not o[1]
                                         else set(self.drains(o[0])) & set(crisis))] if P['forced_agenda'] else []
        if forced:
            # 위기가 안건을 정한다. 위기 법이나, 그 자원을 먹는 법의 폐지만 올릴 수 있다
            self.stats['forced'] += 1
            options = forced
        if self.policy == 'passive' or self.random_laws:
            law, repeal = self.r.choice(options)
        elif self.policy == 'idealist':
            law, repeal = max(options, key=lambda o: self.law_ease(o[0]) + self.r.random())
        else:
            law, repeal = max(options, key=lambda o: self.law_value(o[0], o[1]) + self.r.random() * 0.5)
        self.stats[('rprop_' if repeal else 'prop_') + law] += 1
        kind = LAWS[law]['kind']
        need = 51 if kind == 'normal' else 67
        blocs = self.blocs(law, repeal)
        if 'guided_voting' in self.passed and self.stats['guided_left'] > 0:
            for bl in blocs.values():
                moved = round(bl['und'] * 0.3); bl['yes'] += moved; bl['und'] -= moved
            for c in COMMS: self.rel[c] -= 3
            self.fear += 3
            self.stats['guided_left'] -= 1
        exp0 = self.expected(blocs)
        self.stats['proposals'] += 1
        if repeal: self.stats['repeal_proposals'] += 1
        if exp0 >= need:
            self.stats['easy_laws'] += 1
        deals = []
        if self.policy in ('caretaker', 'idealist', 'schemer') and exp0 < need + 3:
            deals = self.negotiate(blocs, need)
            for c in deals:
                self.promises.append((c, self.seg + 3, self.r.choice(['lever', 'medicine', 'luxury', 'target'])))
        self.stats['deals'] += len(deals)
        if self.policy == 'schemer':
            self.blackmail(blocs, need, deals)
        yes = sum(bl['yes'] for bl in blocs.values())
        for bl in blocs.values():
            p = clamp(0.5 + 0.1 * bl['score'], 0.2, 0.8)
            yes += sum(1 for _ in range(bl['und']) if self.r.random() < p)
        if yes < need:
            self.stats['failed'] += 1
            return  # 부결돼도 약속은 남는다. 그 집단은 약속대로 찬성했다(우리가 정한 규칙)
        if forced: self.stats['forced_passed'] += 1
        if deals and exp0 < need: self.stats['bought_laws'] += 1
        if repeal:
            self.repeal_law(law)
            return
        self.passed.add(law)
        self.passed_at[law] = self.session
        if deals: self.bought_by[law] = (set(deals), self.session)
        self.apply_law(law)
        self.stats['passed'] += 1
        self.stats['pass_' + law] += 1
        if law in HARSH: self.stats['harsh_passed'] += 1
        if law in IDEAL: self.stats['ideal_passed'] += 1

    def leash_tick(self):
        keep = []
        for c, since in self.leashes:
            if self.r.random() < self.grudge[c] * 2 * 0.04:  # 원한 × 비밀 무게(보통 2) × 4%
                self.rel[c] = clamp(self.rel[c] - (self.seg - since) * 3, -100, 100)
                self.trust -= 5
                self.stats['leash_snapped'] += 1
            else:
                keep.append([c, since])
        self.leashes = keep

    def blackmail(self, blocs, need, deals):
        """협박: 비밀 하나로 대표가 집단 전체를 끌고 온다(결속도 1.0). 대가는 적의다."""
        for c in sorted(COMMS, key=lambda c: -SEATS[c]):
            if self.expected(blocs) >= need + 3 or self.secrets < 1:
                break
            bl = blocs[c]
            if c in deals or bl['no'] + bl['und'] == 0:
                continue
            if self.grudge[c] >= P['hostile_grudge']:
                continue  # 열차장을 미워하는 집단은 협박당한 대표를 따르지 않는다(대표 한 표뿐이라 쓰지 않는다)
            # 대표가 끌고 오는 몫: blackmail_pull=1이면 집단 전체(브리프 3.1), 아니면 결속도만큼
            pull = 1.0 if P['blackmail_pull'] else COH0[c]
            moved_n = round(bl['no'] * pull); moved_u = round(bl['und'] * pull)
            bl['yes'] += moved_n + moved_u; bl['no'] -= moved_n; bl['und'] -= moved_u
            self.secrets -= 1
            self.leashes.append([c, self.seg])
            self.offend(c)
            self.blackmails += 1
            self.stats['blackmail'] += 1
            if self.blackmails % P['blackmail_reputation'] == 0:  # 협박이 잦으면 열차 전체가 안다
                for o in COMMS:
                    self.offend(o)
                self.stats['blackmail_known'] += 1

    def drains(self, law):
        """법이 먹는 자원. 위기 때 폐지 안건이 될 수 있다."""
        r = LAWS[law]['res']; out = []
        if r.get('ration_floor') or r.get('food_add', 0) > 0: out.append('food')
        if r.get('heat_floor') or r.get('coal_add', 0) > 0: out.append('coal')
        if r.get('med_mult', 1) > 1: out.append('med')
        return out

    def repeal_law(self, law):
        L = LAWS[law]
        supporters = [c for c in COMMS if self.stance(c, law, grudge=False)[0] >= 3]
        self.passed.discard(law)
        self.repealed_at[law] = self.session
        for c, delta in L['mats'].items():
            for i in range(4):
                self.base[c][i] -= delta[i]
        for c in supporters:  # 좋아하던 법을 빼앗긴 쪽
            self.rel[c] = clamp(self.rel[c] - P['repeal_rel'], -100, 100)
        bought = self.bought_by.pop(law, None)
        if bought and self.session - bought[1] <= 3:  # 약속으로 통과시킨 법을 곧바로 뒤집으면 배신이다
            for c in bought[0]:
                self.offend(c); self.stats['repeal_betrayal'] += 1
        if law in CORPSE:
            self.corpse_issue = True
        self.stats['repealed'] += 1
        self.stats['repeal_' + law] += 1

    def negotiate(self, blocs, need, max_deals=3):
        """공개 협상. 미정 전부와 반대의 20%를 찬성으로 옮긴다. blocs를 바꾸고 거래한 공동체를 돌려준다."""
        open_promise = {p[0] for p in self.promises}
        order = sorted(COMMS, key=lambda c: -(blocs[c]['und'] + blocs[c]['no'] * 0.2))
        done = []
        for c in order:
            if self.expected(blocs) >= need + 3 or len(done) >= max_deals:
                break
            b = blocs[c]
            if (c in open_promise or self.rel[c] <= -40 or b['ide'] <= -3 or b['und'] + b['no'] == 0
                    or self.grudge[c] >= P['hostile_grudge']):
                self.stats['closed_negotiation'] += 1
                continue
            moved = round(b['no'] * 0.2)
            b['yes'] += b['und'] + moved; b['no'] -= moved; b['und'] = 0
            done.append(c)
        return done

    def law_ease(self, law):
        """의회가 얼마나 좋아하나. 이상주의 정책은 이것만 본다."""
        return sum(self.stance(c, law)[0] * SEATS[c] for c in COMMS) / 10

    def law_worth(self, law):
        """남은 구간 동안 법이 아끼거나 쓰는 석탄·식량·의약품(대략, 석탄 1 = 식량 1 = 의약품 0.5)."""
        r = LAWS[law]['res']; left = P['segments'] - self.seg
        heat = self.heat_cost()
        food = sum(self.pop[c] * self.ration[c] for c in COMMS) * P['food_per_person_lever']
        w = -r.get('coal_add', 0) * left - r.get('food_add', 0) * left
        w += heat * (1 - r.get('heat_mult', 1)) * left + food * (1 - r.get('food_mult', 1)) * left
        w += (r.get('haul_mult', 1) - 1) * P['haul_total'] * 0.8 * left
        w += (1 - r.get('med_mult', 1)) * self.injured * P['med_per_injured'] * left * 2
        for c in COMMS:
            w -= max(0, r.get('ration_floor', 0) - self.ration[c]) * self.pop[c] * P['food_per_person_lever'] * left
            w -= max(0, r.get('heat_floor', 0) - self.heat[c]) * self.pop[c] / 40 * P['coal_heat_per_lever'] * left
        w += r.get('food_once', 0) + r.get('heal', 0.4) * 10 - 4
        return w

    def repeal_worth(self, law):
        """폐지로 남은 구간에 아끼는 자원(레버 바닥은 보통 2로 돌아간다고 친다)."""
        r = LAWS[law]['res']; left = P['segments'] - self.seg
        w = r.get('coal_add', 0) * left + r.get('food_add', 0) * left
        for c in COMMS:
            w += max(0, r.get('ration_floor', 0) - 2) * self.pop[c] * P['food_per_person_lever'] * left
            w += max(0, r.get('heat_floor', 0) - 2) * self.pop[c] / 40 * P['coal_heat_per_lever'] * left
        w += (r.get('med_mult', 1) - 1) * self.injured * P['med_per_injured'] * left * 2
        w -= (r.get('haul_mult', 1) - 1) * P['haul_total'] * 0.8 * left
        heat = self.heat_cost()
        food = sum(self.pop[c] * self.ration[c] for c in COMMS) * P['food_per_person_lever']
        w -= heat * (1 - r.get('heat_mult', 1)) * left + food * (1 - r.get('food_mult', 1)) * left
        return w - P['repeal_rel'] / 2  # 지지층을 잃는 값

    def law_value(self, law, repeal=False):
        """생존을 따지는 정책: 자원이 빠듯할수록 자원 효과를 무겁게 본다."""
        tight = clamp((P['plan_line'] - min(self.coal, self.food)) / 60, 0.5, 1.5)
        ease = sum(self.stance(c, law, repeal)[0] * SEATS[c] for c in COMMS) / 10
        need = 51 if LAWS[law]['kind'] == 'normal' else 67
        blocs = self.blocs(law, repeal)
        exp = self.expected(blocs)
        if exp < need and self.policy in ('caretaker', 'schemer'):
            stats = self.stats.copy()
            self.negotiate(blocs, need)
            self.stats = stats
            exp = self.expected(blocs)
        reach = 1.0 if exp >= need else 0.1
        worth = self.repeal_worth(law) if repeal else self.law_worth(law)
        return (worth * tight + ease) * reach

    def promise_tick(self):
        keep = []
        for p in self.promises:
            c, due, kind = p
            if self.seg < due:
                keep.append(p)
                continue
            ok = False
            if kind == 'lever':
                for lever in sorted((self.heat, self.ration), key=lambda lv: lv[c]):
                    if lever[c] < 4 and self.coal > 25 and self.food > 25:
                        lever[c] += 1; ok = True
                        break
            elif kind == 'medicine' and self.med >= 5:
                self.med -= 5; ok = True
            elif kind == 'luxury' and self.lux >= 3:
                self.lux -= 3; ok = True
            elif kind == 'target':
                ok = self.r.random() < P['target_keep']  # 다음 정차를 그 집단 뜻대로
            if ok:
                self.trust += 4; self.rel[c] += 5; self.stats['kept'] += 1
                if self.grudge[c] == 1: self.grudge[c] = 0  # 적의 1은 지킨 약속 하나로 풀린다
            else:
                self.break_promise(p)
        self.promises = keep

    def break_promise(self, p):
        c = p[0]
        self.trust -= 12 if SEATS[c] >= 30 else 8
        self.rel[c] = clamp(self.rel[c] - 20, -100, 100)
        self.fervor[c] = min(3, self.fervor[c] + 1)
        self.tension += 3
        self.stats['broken'] += 1
        self.offend(c)

    def offend(self, c):
        self.grudge[c] = min(3, self.grudge[c] + 1)
        self.last_offense[c] = self.session

    # ---- 계기 ----
    def meters(self):
        avg = sum(self.rel[c] * SEATS[c] for c in COMMS) / 100
        self.trust = clamp(self.trust + clamp(avg / 40, -2.5, 2.5), 0, 100)
        m = self.m
        inc = 0
        for c in COMMS:
            if self.rel[c] <= -40: inc += 3 if c == 'tail' else 2
            elif self.rel[c] <= -15: inc += 1
            if m[c][0] <= 25 or m[c][1] <= 25: inc += 2
        if self.food <= 0: inc += 8
        inc += self.res('tension_add')
        self.fear += self.res('fear_add')
        if inc <= 0:
            self.tension -= 2
        else:
            self.tension += inc * (1 - self.fear / 200)
        self.fear = clamp(self.fear - 1, 0, 100)
        self.tension = clamp(self.tension, 0, 100)
        self.stats['max_tension'] = max(self.stats['max_tension'], int(self.tension))
        self.stats['min_coal'] = min(self.stats.get('min_coal', 999), int(self.coal))
        if self.coal < 20: self.stats['low_coal_segments'] += 1
        if self.food <= 0: self.stats['starving_segments'] += 1

    def check_end(self):
        if self.coal <= 0:
            if not self.stats['emergency_used']:
                self.stats['emergency_used'] = 1
                self.coal += 15; self.tension += 10  # 가구·객차·침목
            else:
                self.end = 'stranded'; return
        if self.trust <= 0 and self.trust_crisis is None:
            self.trust_crisis = self.seg + 3
            self.stats['trust_crisis'] += 1
        if self.trust_crisis is not None:
            if self.trust >= 25:
                self.trust_crisis = None
            elif self.seg >= self.trust_crisis:
                self.end = 'ousted'; return
        if self.tension >= 100:
            self.stats['tension_crisis'] += 1
            if self.r.random() < 0.5 and self.tension_crisis_used < 2:
                self.tension = 65; self.tension_crisis_used += 1
            else:
                self.end = 'revolt'; return
        if any(self.fervor[c] >= 3 for c in COMMS):
            self.stats['fervor3'] += 1

    # ---- 정책 ----
    def policy_levers(self):
        hf, rf = self.res('heat_floor'), self.res('ration_floor')
        for c in COMMS:
            self.heat[c] = max(self.heat[c], int(hf)); self.ration[c] = max(self.ration[c], int(rf))
        if self.policy == 'passive':
            return
        m = self.m
        for c in COMMS:
            w, ra, _, _ = m[c]
            if w < 45 and self.coal > P['lever_line'] and self.heat[c] < 4: self.heat[c] += 1
            if ra < 45 and self.food > P['lever_line'] and self.ration[c] < 4: self.ration[c] += 1
            if w > 65 and self.coal < 40 and self.heat[c] > max(1, hf): self.heat[c] -= 1
            if ra > 65 and self.food < 40 and self.ration[c] > max(1, rf): self.ration[c] -= 1

    def policy_target(self, pid, loot):
        need = {'coal': self.coal / 252, 'food': self.food / 240}
        if self.med < 8:
            need['medicine'] = self.med / 20
        if self.policy == 'passive':
            return max(('coal', 'food'), key=lambda k: loot[k] * (1.5 - need[k]))
        for k in sorted(need, key=need.get):
            if loot.get(k, 0) >= 25:
                return k
        if min(need['coal'], need['food']) > 0.35:
            return max(('luxury', 'symbol', 'secret'), key=lambda k: loot[k])  # 여유가 있으면 정치 물자
        if max(loot['coal'], loot['food']) <= 10 and self.coal < 30:
            return None  # 석탄도 식량도 거의 없는 곳은 지나쳐 석탄을 아낀다
        return max(('coal', 'food'), key=lambda k: loot[k] / (need[k] + 0.05))

    def play(self):
        while self.seg < P['segments'] and self.end is None:
            self.step()
        if self.end is None:
            self.end = 'complete'
        return self


def summarize(policy, n, places):
    ends = Counter(); agg = defaultdict(float)
    rel_end = defaultdict(float)
    for i in range(n):
        run = Run(1000 + i, policy, places).play()
        ends[run.end] += 1
        for k, v in run.stats.items():
            agg[k] += v
        agg['strikes'] += run.strikes
        agg['lost_segments'] += run.lost_segments
        agg['end_trust'] += run.trust
        agg['end_coal'] += run.coal
        agg['end_food'] += run.food
        agg['segments_played'] += run.seg
        for c in COMMS:
            rel_end[c] += run.rel[c]
    print(f'\n## {policy} ({n}판)')
    print('끝:', ', '.join(f'{k} {v / n:.0%}' for k, v in ends.most_common()))
    keys = ['segments_played', 'min_coal', 'low_coal_segments', 'emergency_used', 'end_coal', 'end_food',
            'starving_segments', 'deaths', 'demands', 'demands_refused', 'strikes', 'lost_segments',
            'max_tension', 'tension_crisis', 'trust_crisis', 'end_trust', 'proposals', 'easy_laws',
            'passed', 'deals', 'closed_negotiation', 'kept', 'broken', 'passed_stops',
            'target_coal', 'target_food', 'target_medicine', 'shift_relief', 'strike_conceded', 'fervor3',
            'forced', 'forced_passed', 'bought_laws', 'harsh_passed', 'ideal_passed', 'law_coal', 'law_food',
            'rescued', 'rescue_refused', 'rescue_declined', 'cold_car_outbreak',
            'repeal_proposals', 'repealed', 'repeal_betrayal', 'hostile_blocs', 'blackmail', 'blackmail_known', 'leash_snapped']
    print('평균:', ', '.join(f'{k} {agg[k] / n:.1f}' for k in keys))
    if agg['proposals']:
        print(f"거래 없이도 통과할 법(기댓값 기준): {agg['easy_laws'] / agg['proposals']:.0%}, "
              f"실제 통과: {agg['passed'] / agg['proposals']:.0%}")
    print('끝 관계:', ', '.join(f'{c} {rel_end[c] / n:+.0f}' for c in COMMS))


def main():
    n = 500
    args = sys.argv[1:]
    if args and args[0].isdigit():
        n = int(args.pop(0))
    if args and args[0] == '--tune':
        for kv in args[1:]:
            k, v = kv.split('=')
            P[k] = type(P[k])(float(v)) if isinstance(P[k], float) else int(v)
    places = load_places()
    for policy in ('passive', 'idealist', 'nodeal', 'caretaker', 'schemer', 'caretaker_random'):
        summarize(policy, n, places)


if __name__ == '__main__':
    main()
