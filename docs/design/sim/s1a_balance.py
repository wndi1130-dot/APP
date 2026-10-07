"""S1a 밸런스 확인용 시뮬레이터 (설계 도구, 게임 코드가 아니다).

docs/design/briefs/s1a_politics_numbers.md의 수치로 24구간 판을 자동으로 돌린다.
플레이어는 단순한 규칙으로 움직이는 정책 셋이다.

  passive    레버를 그대로 두고, 요구를 거절하고, 거래하지 않는다.
  caretaker  처지를 견딜 선 안으로 돌보고, 감당할 수 있는 요구는 들어주고, 공개 협상으로 법을 통과시킨다.
  nodeal     caretaker와 같지만 의회에서 거래하지 않는다.

넣지 않은 것: AI 지도자의 뇌물·협박, 사적 부탁, 세력, 결과 아크, 사건 카드의 개별 선택.
사용: python3 docs/design/sim/s1a_balance.py [판 수] [--tune key=value ...]
"""
import json
import math
import random
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]

# ---- 브리프 수치 (조정은 여기서). 시뮬레이션 뒤 고친 값: haul_total 20→32, engine_fatigue, natural_ceiling, engine_exposure0 35→45, strike_rel −40→−15, refuse_rel ----
P = dict(
    segments=24, session_every=3,
    coal0=100, food0=100, med0=20, lux0=8, trust0=50, tension0=20,
    coal_run=6, coal_stop=2, coal_heat_per_lever=0.25, food_per_person_lever=0.025,
    haul_total=32, target_boost=3.0, lever_step=12, winter_every=6, winter_drop=5,
    injury_rate=0.25, death_rate=0.03, med_per_injured=0.5,
    recover_base=1, recover_cap=3, target_keep=0.85,
    engine_fatigue=2.0, shift_relief=10, shift_coal=3,
    natural_ceiling=15, engine_exposure0=45, strike_rel=-15, refuse_rel=5,
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

# 법: 종류, 축, 처지 변화(공동체: (온기, 배급, 과밀, 노출)), 관계 변화, 열림 조건
def d(**kw):
    return kw
LAWS = {
    'secret_ballot': ('normal', (0, -1, 0), {}, {}, lambda s: True),
    'equal_ration': ('normal', (1, 0, 0), d(tail=(0, 15, 0, 0), front=(0, -15, 0, 0)), {}, lambda s: True),
    'contribution_ration': ('normal', (-1, 0, 0), d(engine=(0, 10, 0, 0), guard=(0, 10, 0, 0), tail=(0, -10, 0, 0)), {}, lambda s: True),
    'relocation': ('normal', (1, 0, 0), d(tail=(0, 0, -15, 0), front=(-5, 0, 15, 0)), {}, lambda s: s.m['tail'][2] >= 70),
    'common_heating': ('normal', (1, 0, -1), d(front=(-15, 0, 0, 0), tail=(15, 0, 0, 0)), {}, lambda s: s.m['tail'][0] <= 35),
    'child_labor': ('normal', (-1, -1, 0), d(tail=(0, 0, 0, 10)), {}, lambda s: s.coal <= 30 or s.food <= 30),
    'triage': ('normal', (0, -1, -1), {}, {}, lambda s: s.med <= 5 or s.injured >= 6),
    'rotation': ('normal', (1, 0, 0), d(tail=(0, 0, 0, -20), front=(0, 0, 0, 20)), {}, lambda s: s.m['tail'][3] >= 60),
    'patrol': ('normal', (0, 1, 0), {}, d(tail=-5), lambda s: s.tension >= 40),
    'curfew': ('normal', (0, 1, 0), {}, {}, lambda s: s.seg >= 6),
    'engine_ration': ('normal', (-1, 1, 1), d(engine=(0, 15, 0, 0)), {}, lambda s: s.strike_warned),
    'luxury_levy': ('normal', (1, 0, 0), {}, d(front=-25), lambda s: s.seg >= 9),
    'engine_rite': ('normal', (0, 1, 1), {}, {}, lambda s: True),
    'surveillance': ('normal', (0, 1, 0), {}, {}, lambda s: True),
    'refuse_rescue': ('normal', (0, -1, -1), {}, {}, lambda s: s.m['tail'][2] >= 80),
    'emergency_powers': ('rule', (0, 1, 0), {}, {}, lambda s: s.tension >= 50 or s.trust <= 10),
    'strike_ban': ('rule', (0, 1, 0), {}, d(engine=-30), lambda s: s.strikes > 0),
    'guided_voting': ('rule', (0, 1, 0), {}, {}, lambda s: s.session >= 3),
}
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

    def apply_law_metrics(self, law):
        _, _, mats, rels, _ = LAWS[law]
        for c, delta in mats.items():
            for i in range(4):
                self.base[c][i] += delta[i]
        for c, dr in rels.items():
            self.rel[c] = clamp(self.rel[c] + dr, -100, 100)

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
        heat_coal = sum(self.heat.values()) * P['coal_heat_per_lever']
        food_use = sum(self.pop[c] * self.ration[c] for c in COMMS) * P['food_per_person_lever']
        if 'engine_ration' in self.passed:
            food_use += 1
        if 'common_heating' in self.passed:
            heat_coal -= 0.5
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
        self.meters()
        self.check_end()

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
        if 'child_labor' in self.passed:
            haul *= 1.15
        for k, w in weights.items():
            amt = haul * w / tot
            if k == 'coal': self.coal += amt
            elif k == 'food': self.food += amt
            elif k == 'medicine': self.med += amt
            elif k == 'luxury': self.lux += amt / 3
            elif self.r.random() < amt / 10: self.stats['got_' + k] += 1
        guard_mult = 1.5 if (self.fervor['guard'] >= 1 and self.rel['guard'] <= -40) else 1
        lam = risk * P['injury_rate'] * guard_mult
        inj = sum(1 for _ in range(6) if self.r.random() < lam / 6)
        self.injured += inj
        if self.r.random() < risk * P['death_rate'] * guard_mult:
            self.pop['tail'] -= 1
            self.stats['deaths'] += 1
        self.stats['target_' + target] += 1

    def medicine_tick(self):
        need = self.injured * P['med_per_injured'] * (0.6 if 'triage' in self.passed else 1)
        if self.med >= need:
            self.med -= need
            healed = sum(1 for _ in range(self.injured) if self.r.random() < 0.4)
            self.injured -= healed
        else:
            self.med = 0
            dead = sum(1 for _ in range(self.injured) if self.r.random() < 0.1)
            self.injured -= dead
            self.pop['tail'] -= dead
            self.stats['deaths'] += dead

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
    def stance(self, c, law):
        kind, axes, mats, rels, _ = LAWS[law]
        mat = 0
        if c in mats:
            dw, dr, dc, de = mats[c]
            gain = dw + dr - dc - de
            mat = 2 if gain >= 15 else 1 if gain >= 5 else -2 if gain <= -15 else -1 if gain <= -5 else 0
        if c in rels:
            mat += -2 if rels[c] <= -15 else -1
        ide = sum(a * b for a, b in zip(axes, IDEO[c]))
        return mat + ide + band(self.rel[c]), ide

    def split(self, score):
        if score >= 3: return 0.8, 0.2, 0.0
        if score >= 1: return 0.4, 0.5, 0.1
        if score == 0: return 0.1, 0.8, 0.1
        if score >= -2: return 0.1, 0.5, 0.4
        return 0.0, 0.2, 0.8

    def blocs(self, law):
        out = {}
        for c in COMMS:
            score, ide = self.stance(c, law)
            y, u, n = self.split(score)
            s = SEATS[c]
            yes = round(s * y); no = round(s * n); und = s - yes - no
            out[c] = dict(yes=yes, und=und, no=no, score=score, ide=ide)
        return out

    def expected(self, blocs):
        return sum(b['yes'] + b['und'] * clamp(0.5 + 0.1 * b['score'], 0.2, 0.8) for b in blocs.values())

    def council(self):
        self.session += 1
        open_laws = [l for l, v in LAWS.items() if l not in self.passed and v[4](self)]
        if not open_laws:
            return
        if self.policy == 'passive' or self.random_laws:
            law = self.r.choice(open_laws)
        else:
            law = max(open_laws, key=lambda l: self.law_value(l) + self.r.random())
        kind = LAWS[law][0]
        need = 51 if kind == 'normal' else 67
        blocs = self.blocs(law)
        if 'guided_voting' in self.passed and self.stats['guided_left'] > 0:
            for b in blocs.values():
                moved = round(b['und'] * 0.3); b['yes'] += moved; b['und'] -= moved
            for c in COMMS: self.rel[c] -= 3
            self.fear += 3
            self.stats['guided_left'] -= 1
        exp0 = self.expected(blocs)
        self.stats['proposals'] += 1
        if exp0 >= need:
            self.stats['easy_laws'] += 1
        deals = 0
        if self.policy == 'caretaker' and exp0 < need + 3:
            open_promise = {p[0] for p in self.promises}
            order = sorted(COMMS, key=lambda c: -(blocs[c]['und'] + blocs[c]['no'] * 0.2))
            for c in order:
                if self.expected(blocs) >= need + 3 or deals >= 3:
                    break
                b = blocs[c]
                if c in open_promise or self.rel[c] <= -40 or b['ide'] <= -3 or b['und'] + b['no'] == 0:
                    self.stats['closed_negotiation'] += 1
                    continue
                moved = round(b['no'] * 0.2)
                b['yes'] += b['und'] + moved; b['no'] -= moved; b['und'] = 0
                self.promises.append((c, self.seg + 3, self.r.choice(['lever', 'medicine', 'luxury', 'target'])))
                deals += 1
        self.stats['deals'] += deals
        yes = sum(b['yes'] for b in blocs.values())
        for b in blocs.values():
            p = clamp(0.5 + 0.1 * b['score'], 0.2, 0.8)
            yes += sum(1 for _ in range(b['und']) if self.r.random() < p)
        if yes >= need:
            self.passed.add(law)
            self.apply_law_metrics(law)
            self.stats['passed'] += 1
            if law == 'guided_voting':
                self.stats['guided_left'] = 3
            if law == 'engine_rite' or law == 'engine_ration':
                self.fervor['engine'] = max(0, self.fervor['engine'] - 1)
            if law == 'luxury_levy':
                self.lux += 5
            if law in ('triage', 'refuse_rescue'):
                self.trust -= 5
            if law == 'surveillance':
                self.trust -= 3
        else:
            self.stats['failed'] += 1
            # 부결돼도 약속은 남는다. 그 집단은 약속대로 찬성했다(우리가 정한 규칙)

    def law_value(self, law):
        val = 0
        for c in COMMS:
            score, _ = self.stance(c, law)
            val += score * SEATS[c] / 10
        return val

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
        if 'patrol' in self.passed:
            inc -= 1; self.fear += 2
        if 'surveillance' in self.passed: self.fear += 2
        if 'curfew' in self.passed: self.fear += 1
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
        if self.policy == 'passive':
            return
        m = self.m
        for c in COMMS:
            w, ra, _, _ = m[c]
            if w < 45 and self.coal > 60 and self.heat[c] < 4: self.heat[c] += 1
            if ra < 45 and self.food > 60 and self.ration[c] < 4: self.ration[c] += 1
            if w > 65 and self.coal < 40 and self.heat[c] > 1: self.heat[c] -= 1
            if ra > 65 and self.food < 40 and self.ration[c] > 1: self.ration[c] -= 1

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
            'target_coal', 'target_food', 'target_medicine', 'shift_relief', 'strike_conceded', 'fervor3']
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
    for policy in ('passive', 'nodeal', 'caretaker', 'nodeal_random', 'caretaker_random'):
        summarize(policy, n, places)


if __name__ == '__main__':
    main()
