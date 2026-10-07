"""S1b 어두운 길 시뮬레이터 (설계 도구, 게임 코드가 아니다).

docs/design/briefs/s1b_dark_path.md의 제안 규칙(4장 불씨 사다리·수사·군중·희생양·암살 명령, 5장 탄압·계엄,
5.5 내전 직전과 내전, 9.1 칸 안 시신, 10.2 수단 점수)을 s1a_balance.py의 Run 위에 얹어 돌린다.
s1a_balance.py는 고치지 않는다. S1b 판의 주사위는 따로 굴려(r2) S1a 쪽 흐름을 건드리지 않는다.

정책 (S1b 켬. 회기 운영은 saint·caretaker·tyrant가 S1a caretaker, schemer_plus가 S1a schemer)
  saint         선을 넘지 않는다. 늘 수사·재판(사보타주도 수사), 군중엔 재판 약속·보호, 탄압·계엄·희생양 없음.
  caretaker     폭행·암살 임박에만 경비를 붙이고, 증거가 서면 재판, 아니면 더 캔다. 긴장 80을 넘을 때만 희생양.
                내전 직전엔 신임 40 이상이면 휴전 서약, 아니면 떼어 놓는다.
  tyrant        징후마다 경비, 항의·파업마다 강제 해산, 수사는 즉결(벌은 추방), 군중이 오면 바로 희생양,
                대권이 끝나면 계엄(대권 연장 문), 내전 직전·내전엔 계엄 선포나 큰 쪽 편들기,
                적의 3이 된 칸 대표와 약점을 쥔 실행자를 암살한다(판당 Q['assn_cap']번).
  schemer_plus  schemer(협박)에 암살(적의 3 대표, 실행자 입막음)과 누명을 더한다. 내전 직전엔 편을 든다.
S1a 정책(passive, idealist, nodeal, caretaker, schemer, caretaker_random)은 S1b를 끄면 s1a_balance.Run과 판마다 같다.

사용: python3 docs/design/sim/s1b_dark.py [판 수=1000] [--baseline] [--policies a,b] [--tune key=value ...]
  판 수           정책마다 몇 판(씨앗 1000, 1001, ...). 같은 명령은 언제나 같은 숫자를 낸다.
  --baseline      S1b 판 앞에, S1b를 끈 DarkRun이 S1a 정책 여섯에서 s1a_balance.Run과 판마다 같은지 센다
                  ('s1a와 같은 판 n/n'). S1b 판 결과는 바꾸지 않는다.
  --policies      돌릴 S1b 정책(쉼표로). 기본은 saint,caretaker,tyrant,schemer_plus. caretaker가 있어야 목표 확인이 나온다.
  --tune          이 파일의 Q와 s1a_balance의 P를 판 전에 바꾼다(예: --tune esc_base=0.25 rival_p=0.1).

기본값: 브리프 3판 16.1 표의 수치(esc_base 0.32, quiet_out 8, disperse_tension 6, leash_public 0.5,
  brink_tension 101 = 긴장 70 길 없음)에 3라운드의 휴전 서약 조건(truce_cond 1)을 더했다.
  `--tune truce_cond=0`이면 16.1 표가 그대로 나온다. 3라운드 제안(폭력 긴장 낮춤)은
  `--tune threat_tension=1 assault_tension=3 assn_tension=3 brink_seg_tension=1`.

Q의 손잡이 (자세한 값은 아래 Q 주석)
  사다리       ember_p(원인 → 불씨 확률, 0이면 사다리 끔), rival_p(원수 대표가 표결에서 갈릴 때), esc_base(오르는 확률),
               quiet_out(조용한 구간 수만큼 지나면 꺼짐), guard_post_line, guard_len/guard_max, armory, theft_p, desert_p, fear_haul
  긴장 출처    threat_tension/threat_fear(위협), assault_tension(폭행), assn_tension(암살), brink_seg_tension(내전 직전 구간마다),
               disperse_tension(강제 해산), ml_tension(계엄 구간마다)
  끄기(시험)   crowd=0(군중 시계 없음), sab_on=0(사보타주 손해 없음), guard_fear/guard_expo=0(경비 붙일 때 값 없음),
               floor=0(관계 바닥 환산 없음), corpse_cost=0(시신 확인 값 없음), trial_slot=0(재판이 법 자리를 안 먹음)
  계엄         ml_rel(대권 연장 문의 경비대 관계, 15 = 호의), ep_normal=1(비상대권을 51표로), ml_direct, ml_lift, coup_*
  내전         brink_tension(101이면 긴장 길 없음), brink_clock, truce_cond(서약 조건), truce_sep, ai_ml_request, captain_ambition
  협박 값      leash_public(목줄이 끊기면 공개될 확률), harsh_pull
"""
import random
import sys
from collections import Counter, defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import s1a_balance as A  # noqa: E402
from s1a_balance import P, COMMS, SEATS, LAWS, HARSH, IDEAL, CORPSE, OPPOSITE, band  # noqa: E402

_RAW = [0.0]


def clamp(x, lo, hi):
    """s1a의 clamp와 같은 값. 관계 바닥 환산(2판)을 위해 자르기 전 값을 남긴다."""
    _RAW[0] = x
    return max(lo, min(hi, x))


A.clamp = clamp  # 같은 값을 돌려주니 S1a 결과는 그대로다(--baseline으로 확인)


class RelDict(dict):
    """관계가 −100 아래로 깎이면 그 몫을 run.floor_debt로 넘긴다."""
    def __init__(self, run, d):
        super().__init__(d)
        self.run = run

    def __setitem__(self, c, v):
        run = self.run
        if v <= -100 and run.floor_on and Q['floor']:
            raw = v if v < -100 else min(-100, _RAW[0])
            if raw < -100:
                run.floor_debt(c, -100 - raw)
            v = -100
        _RAW[0] = 0.0
        super().__setitem__(c, v)

class SortedSet(set):
    """이름 순으로 도는 집합. s1a의 self.passed는 보통 set이라 도는 순서가 PYTHONHASHSEED에 따라 바뀌고,
    회기 안건 고르기(max + 주사위)가 프로세스마다 달라진다(판 결과 ±1%p). S1b 판에서만 순서를 고정한다."""
    def __iter__(self):
        return iter(sorted(set.__iter__(self)))


# ---- S1b 제안 수치 (브리프 절 번호). 브리프에 없는 값은 (가정) ----
Q = dict(
    # 4.1 불씨
    ember_p=1.0,          # (가정, 2라운드 기준선) 원인이 생기면 불씨가 생길 확률. 1판 기본 0.5
    rival_p=0.2,          # 원수 대표가 같은 표결에서 갈렸을 때
    esc_base=0.32, esc_lack=0.10, esc_opp=0.10, esc_guard=0.15, esc_patrol=0.10, esc_min=0.05, esc_max=0.65,
    ember_max=2, violent_cap=3,
    quiet_out=8,          # 브리프 4구간. 2라운드 기준선은 8(조정)
    guard_post_line=0,    # (가정) caretaker류는 경비대 노출이 이 아래일 때만 기척·위협·사보타주에 경비를 붙인다(0 = 폭행·암살 임박에만)
    guard_len=2, guard_max=2,  # 경비 2명이 2구간, 동시에 두 곳까지(4.2, 2판)
    curfew_esc=0.10,      # 통행 금지: 오르는 확률 −10%(2판, 새 불씨를 막지 않는다)
    lack_line=25, starve_line=20, theft_p=0.3,  # 굶주림의 도둑질(사다리 밖, 2판)
    floor_drift=0,        # (가정) 0이면 처지에 따른 관계 하락(drift)은 바닥 환산에서 뺀다. 칼질·탄압 같은 '깎음'만 센다
    armory=1, assault_death_armory=0.10,  # 무기고 통제(4.1 예방, 2판). 정책 모두 받아들인다(가정)
    fear_haul=0.9, desert_p=0.25,  # 공포 40 이상: 정차 산출 −10%, 탈주 확률(가정) 구간당 25%에 식량 2~4
    # 4.1 사다리
    assault_death=0.2, assn_base=0.5, assn_guard=0.2, assn_guardcap=0.2,
    # 4.4 수사
    clue_true=0.40, clue_cap=0.75, false_mult=0.5, false_mult_fear=0.7, reveal_p=0.10, reveal_window=6, cold_case=8,
    # 4.5 군중
    clock_death=2, clock_injury=3, scapegoat_death=0.6, scapegoat_tension=80, protect_hurt=0.3,
    # 4.6 암살 명령
    order_base=0.55, order_exposed_fail_caught=0.5, order_names_chief=0.7, leaderless=1,
    assn_cap=2,           # 판당 두 번까지(2판)
    assn_on_fail=0,       # 1판 시뮬레이터의 열림(위기 법 부결 뒤). 2판은 상황 카드에서만 연다
    exec_blackmail_p=0.2,  # (가정) 실행자 칸 관계가 회의 이하일 때 구간마다 열차장 협박 확률
    # 5.1 탄압, 5.3 계엄
    repress_extinguish=1, disperse_tension=6,  # 탄압이 그 칸 불씨를 끈다(5.1). 0이면 끄지 않는다(시험)
    guard_refuse=0.5, ep_len=3, coup_line=-15, coup_clear=15, coup_wait=2, curfew=1, ml_direct=0, ml_lift=0,
    ml_tension=2, decree_guard=-5,  # 계엄 긴장 +2/구간, 포고마다 경비대 관계 −5(2판)
    ep_normal=0,          # 1이면 비상대권을 일반 51표로(코디네이터 C-2 시험)
    brink_max=2, war_max=1, brink_clock=3, brink_tension=101, brink_esc=0.20,  # 5.5 내전 직전(3판)
    ai_ml_request=0.4, pledge_cost=6, support_rel=10, war_help_trust=-10,
    captain_ambition=0.3,  # (가정) 경비대장 성향이 야심일 확률
    leash_public=0.5,     # D-1: 목줄이 끊기면 이 확률로 대표가 공개(신임 −10, 그 칸 적의 +1, 결과 아크 +1)
    harsh_pull=0.0,       # D-2: 0이 아니면 가혹 법의 협박은 대표 몫 = 의석 × 결속도 × 이 값만 끌고 온다
    ml_rel=15, ml_grudge_max=0,  # 계엄 조건: 경비대 관계 호의 이상, 경비대장 적의 0
    tyrant_blackmail=0,   # (가정) 1이면 tyrant도 schemer처럼 협박한다(비상대권 67표를 모으는 길)
    tyrant_ep_bonus=40,   # (가정) tyrant가 비상대권 안건을 고르는 가중
    # 9.1 시신
    corpse_rise=0.25, vigil_p=0.3, vigil_guarded=0.10, car_miss=0.10,
    trial_defer=1,        # (가정) 위기 강제 안건이 있으면 재판을 다음 회기로 미룬다
    # 3라운드: 휴전 서약 조건(5.5)
    truce_cond=1,         # 1이면 서약이 통과해도 두 집단의 조건(S1a 3.2 열린 협상 조건)을 시계 안에 지켜야 멈춘다. 0이면 통과만으로 멈춘다(2라운드)
    truce_sep=0,          # (가정) 1이면 서약 뒤 조건이 남은 채 마지막 구간이면 떼어 놓기로 한 구간 번다
    # 3라운드: 긴장 출처를 하나씩 끄는 손잡이(기본값 = 브리프 값)
    threat_tension=3, threat_fear=2,   # 위협(사다리 1)
    assault_tension=6,    # 폭행(사다리 3)
    assn_tension=6,       # 암살(사다리 4)
    brink_seg_tension=3,  # 내전 직전 구간마다
    crowd=1,              # 0이면 군중 시계가 없다(사건은 수사만)
    sab_on=1,             # 0이면 사보타주가 물자·사람에 손해를 주지 않는다(사다리 칸은 그대로)
    guard_fear=2, guard_expo=3,  # 경비를 붙일 때 공포·경비대 노출
    floor=1,              # 0이면 관계 바닥 환산(적의·불씨)이 없다
    trial_slot=1,         # 0이면 재판이 회기의 법 안건 자리를 먹지 않는다(시험)
    corpse_cost=1,        # 0이면 칸 안 시신 확인·밤샘의 관계·노출 값이 없다(일어나는 시신도 없다)
)
RIVALS = [('tail', 'front'), ('engine', 'medtech'), ('guard', 'tail')]  # (가정) 원수 관계 = S1a OPPOSITE 짝
BASE = dict(saint='caretaker', caretaker='caretaker', tyrant='caretaker', schemer_plus='schemer')
DARK = ('saint', 'caretaker', 'tyrant', 'schemer_plus')
MEANS = dict(assn_ordered=4, ml_means=1, executions=3, scapegoats=3, frames=3, exiles=2, lynch_allowed=2,
             mass_arrest=2, summary=2, trial_bought=2, dispersals=1, blackmail=1, harsh_chosen=1)
S1A_POLICIES = ('passive', 'idealist', 'nodeal', 'caretaker', 'schemer', 'caretaker_random')


def rivals(a, b):
    return (a, b) in RIVALS or (b, a) in RIVALS


class DarkRun(A.Run):
    def __init__(self, seed, policy, places, s1b=True):
        self.s1b = s1b
        self.dark = policy if s1b else None
        base = BASE.get(policy, policy) if s1b else policy
        if s1b and policy == 'tyrant' and Q['tyrant_blackmail']:
            base = 'schemer'
        super().__init__(seed, base, places)
        if not s1b:
            return
        self.passed = SortedSet(self.passed)  # 프로세스마다 같은 결과(위 SortedSet)
        self.r2 = random.Random(seed * 7919 + 17)  # S1b 전용 주사위. S1a 쪽 흐름은 건드리지 않는다
        self.ideo = {c: list(A.IDEO[c]) for c in COMMS}
        self.embers, self.cases, self.innocents = [], [], []   # innocents: [칸, 벌받은 구간]
        self.punished_comms = []
        self.violent_used = 0
        self.chief_attacked = False
        self.prev_fervor = {c: 0 for c in COMMS}
        self.prev_grudge = {c: 0 for c in COMMS}
        self.lack_streak = {c: 0 for c in COMMS}
        self.repressed_until = {c: -1 for c in COMMS}
        self.dispersed = Counter()
        self.fresh_corpses, self.unchecked, self.hidden_bites = [], [], []
        self.practice = None
        self.scheduled = []
        self.ep_on, self.ep_left, self.ep_decrees = False, 0, []
        self.ml, self.ml_start, self.pre_ml_trust, self.coup_warn, self.ml_floor = False, None, None, None, None
        self.leaderless = set()
        self.order = None
        self.executors = []
        self.haul_once = 1.0
        self._phase = None
        self._last_vote = None
        self._snapped = []
        self.eid = 0
        self.crisis_open = {}
        self.rel_debt = Counter()
        self.floor_on = True
        self.rel = RelDict(self, self.rel)
        self.armory = self.armory_asked = False
        self.ration_streak = {c: 0 for c in COMMS}
        self.brink = self.war = None
        self.brinks_n = self.wars_n = 0
        self.captain_ambitious = self.r2.random() < Q['captain_ambition']
        self.coup_line_now = Q['coup_line']

    # ---------------- S1a 훅 ----------------
    def res(self, key, default=0.0):
        v = super().res(key, default)
        if key == 'haul_mult' and self.s1b:
            v *= self.haul_once * (Q['fear_haul'] if self.fear >= 40 else 1)
        return v

    def on_death(self, n, c='tail'):
        super().on_death(n, c)
        if self.s1b and self._phase == 'medicine' and n > 0:
            self.fresh_corpses += [c] * n  # 약이 없어 죽은 부상자: 칸 안의 죽음

    def stance(self, c, law, repeal=False, grudge=True):
        if not self.s1b:
            return super().stance(c, law, repeal, grudge)
        L = LAWS[law]
        axes, mats, rels = L['axes'], L['mats'], L['rels']
        mat = L['like'].get(c, 0)
        if c in mats:
            dw, dr, dc, de = mats[c]
            gain = dw + dr - dc - de
            mat += 2 if gain >= 15 else 1 if gain >= 5 else -2 if gain <= -15 else -1 if gain <= -5 else 0
        if c in rels:
            mat += -2 if rels[c] <= -15 else -1
        ide = sum(a * b for a, b in zip(axes, self.ideo[c]))  # 승계로 더 과격해진 이념
        if repeal:
            mat, ide = -mat, -ide
        score = mat + ide + band(self.rel[c])
        if grudge and self.grudge[c] >= P['hostile_grudge']:
            score = min(score, -3)
        elif grudge and self.grudge[c] >= 1:
            score -= 1
        return score, ide

    def blocs(self, law, repeal=False):
        out = super().blocs(law, repeal)
        if self.s1b:
            for c in self.leaderless:  # 대표를 잃은 집단은 다음 표결에서 누구도 따르지 않는다(가정)
                b = out[c]; b['und'] += b['no']; b['no'] = 0; b['score'] = 0
            self._last_vote = (law, repeal, out)
        return out

    def law_value(self, law, repeal=False):
        v = super().law_value(law, repeal)
        if self.s1b and self.dark == 'tyrant' and law == 'emergency_powers' and not repeal:
            v += Q['tyrant_ep_bonus'] * (1.0 if v > -999 else 0)
        return v

    def policy_levers(self):
        super().policy_levers()
        if self.s1b and self.ml:
            self.ration['guard'] = max(self.ration['guard'], self.ml_floor)
            if self.coup_warn is not None or self.rel['guard'] < 15:  # 충성을 사려고 경비대를 먹이고 데운다
                if self.food > 20: self.ration['guard'] = min(4, self.ration['guard'] + 1)
                if self.coal > 20: self.heat['guard'] = min(4, self.heat['guard'] + 1)

    def leash_tick(self):
        if not self.s1b:
            return super().leash_tick()
        keep = []
        for c, since in self.leashes:
            if self.r.random() < self.grudge[c] * 2 * 0.04:
                self.rel[c] = clamp(self.rel[c] - (self.seg - since) * 3, -100, 100)
                self.trust -= 5
                self.stats['leash_snapped'] += 1
                self._snapped.append(c)
                if Q['leash_public'] and self.r2.random() < Q['leash_public']:  # D-1: 대표가 공개한다
                    self.trust -= 10; self.offend(c)
                    self.stats['leash_public'] += 1; self.stats['arc'] += 1
            else:
                keep.append([c, since])
        self.leashes = keep

    def blackmail(self, blocs, need, deals):
        """D-2: 가혹 법이면 협박당한 대표는 의석 × 결속도 × harsh_pull만 끌고 온다. 나머지는 s1a 그대로."""
        if not self.s1b or not Q['harsh_pull']:
            return super().blackmail(blocs, need, deals)
        law, repeal = (self._last_vote[0], self._last_vote[1]) if self._last_vote else (None, False)
        harsh = law in HARSH and not repeal
        for c in sorted(COMMS, key=lambda c: -SEATS[c]):
            if self.expected(blocs) >= need + 3 or self.secrets < 1:
                break
            bl = blocs[c]
            if c in deals or bl['no'] + bl['und'] == 0:
                continue
            if self.grudge[c] >= P['hostile_grudge']:
                continue
            if harsh:
                share = round(SEATS[c] * A.COH0[c] * Q['harsh_pull'])  # 대표가 끌고 오는 표 수
                moved_n = min(bl['no'], share); moved_u = min(bl['und'], share - moved_n)
                self.stats['blackmail_harsh'] += 1
            else:
                pull = 1.0 if P['blackmail_pull'] else A.COH0[c]
                moved_n = round(bl['no'] * pull); moved_u = round(bl['und'] * pull)
            bl['yes'] += moved_n + moved_u; bl['no'] -= moved_n; bl['und'] -= moved_u
            self.secrets -= 1
            self.leashes.append([c, self.seg])
            self.offend(c)
            self.blackmails += 1
            self.stats['blackmail'] += 1
            if self.blackmails % P['blackmail_reputation'] == 0:
                for o in COMMS:
                    self.offend(o)
                self.stats['blackmail_known'] += 1

    def check_end(self):
        if not self.s1b or not self.ml:
            return super().check_end()
        # 계엄: 신임 위기로 축출되지 않는다(쿠데타는 pre_move에서)
        if self.coal <= 0:
            if not self.stats['emergency_used']:
                self.stats['emergency_used'] = 1
                self.coal += 15; self.tension += 10
            else:
                self.end = 'stranded'; return
        if self.tension >= 100:
            self.stats['tension_crisis'] += 1
            if self.r.random() < 0.5 and self.tension_crisis_used < 2:
                self.tension = 65; self.tension_crisis_used += 1
            else:
                self.end = 'revolt'; return
        if any(self.fervor[c] >= 3 for c in COMMS):
            self.stats['fervor3'] += 1

    # ---------------- 구간 ----------------
    def step(self):
        if not self.s1b:
            return super().step()
        self.seg += 1
        self.track_crises()  # 정책이 대응하기 전, 구간 시작의 상태로 잰다
        if self.seg % P['winter_every'] == 0:
            for c in COMMS:
                self.base[c][0] -= P['winter_drop']
        self.policy_levers()
        self.pre_move()
        if self.end:
            return
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
        self.move_phase()
        if not striking:
            self.base['engine'][3] += P['engine_fatigue']
            self._phase = 'stop'; self.stop(); self._phase = None
        self.haul_once = 1.0
        self._phase = 'medicine'; self.medicine_tick(); self._phase = None
        self.floor_on = bool(Q['floor_drift']); self.drift(); self.floor_on = True
        self.demands()
        if self.seg % P['session_every'] == 0:
            self.council()
        self.promise_tick()
        self.leash_tick()
        self.settle()
        self.meters()
        self.check_end()

    # ---- 위기가 얼마나 빨리 끝나나 (코디네이터 요청) ----
    def crisis_states(self):
        return dict(
            strike=(self.fervor['engine'] >= 1 and self.rel['engine'] <= P['strike_rel']
                    and 'strike_ban' not in self.passed),                           # 기관실 파업 조건
            protest=self.fervor['tail'] >= 1 and self.rel['tail'] <= -40,           # 꼬리칸 작업 거부
            resource=self.coal < P['crisis_line'] or self.food < P['crisis_line'],  # 위기 강제 안건이 걸리는 자원
        )

    def track_crises(self):
        S = self.stats
        for t, on in self.crisis_states().items():
            start = self.crisis_open.get(t)
            if on and start is None:
                self.crisis_open[t] = self.seg; S['crisis_%s_n' % t] += 1
            elif not on and start is not None:
                self.crisis_done(t, self.seg - start)
        for case in self.cases:  # 군중 위기: 사람이 다친 사건이 열린 뒤 누군가 벌받거나 닫힐 때까지
            if case['crowd'] and not case.get('recorded'):
                if not case.get('counted'):
                    case['counted'] = True; S['crisis_crowd_n'] += 1
                if case['status'] == 'closed':
                    case['recorded'] = True
                    self.crisis_done('crowd', max(1, self.seg - 1 - case['opened']))

    def crisis_done(self, t, dur):
        S = self.stats
        self.crisis_open.pop(t, None)
        S['crisis_%s_resolved' % t] += 1
        S['crisis_%s_dur' % t] += dur
        if dur <= 1:
            S['crisis_%s_fast' % t] += 1

    # ---- 출발 전 운영 ----
    def pre_move(self):
        S = self.stats
        due = [s for s in self.scheduled if s[0] <= self.seg]
        self.scheduled = [s for s in self.scheduled if s[0] > self.seg]
        for _, fn in due:
            fn()
        if self.ml:
            S['ml_segments'] += 1
            self.base['guard'][3] += 2
            self.tension += Q['ml_tension']; self.fear += 3
            if Q['curfew']:
                self.tension += 1; self.fear += 2
                for c in ('tail', 'front'): self.rel[c] = clamp(self.rel[c] - 2, -100, 100)
            if self.rel['guard'] <= self.coup_line_now and self.coup_warn is None:
                self.coup_warn = self.seg; S['coup_warning'] += 1
            if self.coup_warn is not None:
                if self.rel['guard'] >= Q['coup_clear']:
                    self.coup_warn = None
                elif self.seg - self.coup_warn >= Q['coup_wait']:
                    if Q['ml_lift'] and self.dark == 'tyrant':
                        self.lift_ml()
                    else:
                        self.end = 'coup'; return
        if self.ep_on:
            if self.ep_left > 0:
                law = self.decree()
                if law: self.ep_decrees.append(law)
                self.ep_left -= 1
            else:
                self.ep_expire()
        elif (self.dark == 'tyrant' and Q['ml_direct'] and not self.ml
              and (self.tension >= 50 or self.trust <= 10) and self.ml_ok()):
            self.declare_ml('extend')
        if self.war:
            self.war_card()
        elif self.brink:
            self.brink_card()
        if self.dark == 'tyrant':
            for c in ('engine', 'tail'):
                line = P['strike_rel'] if c == 'engine' else -40
                if c == 'engine' and 'strike_ban' in self.passed:
                    continue
                if self.fervor[c] >= 1 and self.rel[c] <= line:
                    self.disperse(c)
        self.investigate()
        self.escalate()

    # ---- 이동 ----
    def move_phase(self):
        for e in list(self.embers):
            if e['imm'] is not None:
                self.act(e)
        if self.order:
            self.execute_order()

    # ---- 정산 ----
    def settle(self):
        S = self.stats
        m = self.m
        # 숨긴 물림
        keep = []
        for comm, since in self.hidden_bites:
            if 'patrol' in self.passed or self.r2.random() < 0.5:
                S['bites_found'] += 1; self.trust -= 4
                self.train_death(1, comm)
            elif self.seg - since >= 2:
                S['bite_outbreak'] += 1
                self.tension += 8; self.fear += 5; self.injured += 1
                self.train_death(1, comm)
            else:
                keep.append([comm, since])
        self.hidden_bites = keep
        # 확인하지 않은 시신이 일어난다
        for comm, p in self.unchecked:
            if self.r2.random() < p:
                S['corpse_rise'] += 1
                self.hidden_bites.append([comm, self.seg])
        self.unchecked = []
        # 이번 구간 칸 안의 죽음: 머리 확인
        i = 0
        while i < len(self.fresh_corpses):
            self.check_corpse(self.fresh_corpses[i]); i += 1
        self.fresh_corpses = []
        # 군중 시계
        for case in list(self.cases):
            if case['status'] in ('open', 'trial') and case['clock'] is not None and case['opened'] < self.seg:
                case['clock'] -= 1
                if case['clock'] <= 0:
                    self.crowd_card(case)
        # 진실이 드러난다
        keep = []
        for comm, s0 in self.innocents:
            if self.seg - s0 > Q['reveal_window']:
                continue
            if self.r2.random() < Q['reveal_p']:
                S['truth_revealed'] += 1; self.trust -= 10; self.offend(comm)
            else:
                keep.append([comm, s0])
        self.innocents = keep
        # 실행자가 쥔 약점: 협박 카드에 '조용히 처리한다'가 붙는다(4.6)
        for comm in list(self.executors):
            if self.rel[comm] <= -15 and self.r2.random() < Q['exec_blackmail_p']:
                S['executor_blackmail'] += 1
                if not self.order_assassination(comm, 'silence', guard_mod=0.0):
                    if self.lux >= 3: self.lux -= 3
                    else: self.food -= 5
        # 공포 40 이상: 탈주자가 식량을 들고 간다(5.2, 2판)
        if self.fear >= 40 and self.r2.random() < Q['desert_p']:
            S['deserters'] += 1; self.pop['tail'] -= 1; self.food -= self.r2.uniform(2, 4)
        self.starving_theft()
        # 불씨가 꺼진다: 원인이 풀렸거나 4구간 조용했다
        for e in list(self.embers):
            if e['imm'] is not None:
                continue
            w, ra = m[e['who']][0], m[e['who']][1]
            solved = ((e['cause'] == 'fervor' and self.fervor[e['who']] <= 1)
                      or (e['cause'] == 'grudge' and self.grudge[e['who']] <= 1)
                      or (e['cause'] == 'lack' and w >= 45 and ra >= 45))
            if solved:
                self.kill_ember(e, 'ember_resolved')
            elif e['quiet'] >= Q['quiet_out']:
                self.kill_ember(e, 'ember_quiet')
        # 불씨가 생긴다
        for c in COMMS:
            if self.fervor[c] >= 2 and self.prev_fervor[c] < 2:
                self.new_ember(c, 'guard' if c != 'guard' else 'chief', 'fervor')
            if self.grudge[c] >= 2 and self.prev_grudge[c] < 2:
                self.new_ember(c, 'aide', 'grudge')
            if self.grudge[c] >= 3 and self.prev_grudge[c] < 3:  # 적의 3 지도자가 불신임을 올리려 한다(4.6 카드)
                self.order_assassination(c, 'hostile')
            if m[c][0] <= Q['starve_line'] or m[c][1] <= Q['starve_line']:
                self.lack_streak[c] += 1
                if self.lack_streak[c] >= 2:
                    self.lack_streak[c] = 0
                    self.new_ember(c, 'store' if c != 'front' else 'aide', 'lack')
            else:
                self.lack_streak[c] = 0
        for c in self._snapped:
            self.new_ember(c, 'chief', 'leash')
        self._snapped = []
        self.brink_tick()
        self.prev_fervor = dict(self.fervor)
        self.prev_grudge = dict(self.grudge)

    # ---------------- 불씨와 사다리 (4.1~4.3) ----------------
    def curfew_on(self):
        return self.ml and Q['curfew']

    def floor_debt(self, c, over):
        """관계 바닥(−100)에서 더 깎인 몫: 10마다 적의 +1, 적의 3이면 불씨 하나(4.1, 2판)."""
        self.rel_debt[c] += over
        while self.rel_debt[c] >= 10:
            self.rel_debt[c] -= 10
            self.stats['floor_converted'] += 1
            if self.grudge[c] < 3:
                self.offend(c)
            else:
                self.new_ember(c, 'chief', 'floor')

    def new_ember(self, who, target, cause, p=None):
        S = self.stats
        S['ember_trigger'] += 1
        p = Q['ember_p'] if p is None else p
        if self.seg <= self.repressed_until[who]:
            p *= 2
        if self.fear >= 80:
            p *= 0.7
        if self.r2.random() >= min(1.0, p):
            return
        if any(e['who'] == who and e['target'] == target for e in self.embers):
            return
        if len(self.embers) >= Q['ember_max']:
            S['ember_capped'] += 1; return
        self.eid += 1
        e = dict(id=self.eid, who=who, target=target, cause=cause, stage=1 if self.fear >= 80 else 0,
                 imm=None, quiet=0, guard_until=-1, sab=None, blocked=False)
        self.embers.append(e)
        S['embers'] += 1; S['sign_kiche'] += 1; S['ember_' + cause] += 1
        if self.wants_guard(stage=0):
            self.post_guard(e)

    def wants_guard(self, stage):
        if self.dark == 'tyrant' or stage >= 3:
            return True
        return self.m['guard'][3] < Q['guard_post_line']

    def guarded(self, e):
        return e['guard_until'] >= self.seg

    def post_guard(self, e):
        """경비 2명이 2구간 선다. 동시에 두 곳까지(4.2, 2판)."""
        if self.guarded(e):
            return
        if sum(1 for x in self.embers if self.guarded(x)) >= Q['guard_max']:
            self.stats['guard_unavailable'] += 1
            return
        e['guard_until'] = self.seg + Q['guard_len'] - 1
        self.fear += Q['guard_fear']; self.base['guard'][3] += Q['guard_expo']
        self.stats['guard_posted'] += 1

    def kill_ember(self, e, why):
        if e in self.embers:
            self.embers.remove(e)
            self.stats[why] += 1

    def esc_prob(self, e):
        m = self.m[e['who']]
        p = Q['esc_base']
        p += Q['esc_lack'] * ((m[0] <= Q['lack_line']) + (m[1] <= Q['lack_line']))
        opp = (self.fervor['guard'] >= 1 and self.rel['guard'] <= -40) + (self.ml and not Q['curfew'])
        p += Q['esc_opp'] * opp
        p -= Q['esc_guard'] * self.guarded(e) + Q['esc_patrol'] * ('patrol' in self.passed)
        p -= Q['curfew_esc'] * self.curfew_on()
        if self.brink and {e['who'], e['target']} == set(self.brink['pair']):
            p += Q['brink_esc']
        return clamp(p, Q['esc_min'], Q['esc_max'])

    def escalate(self):
        S = self.stats
        for e in list(self.embers):
            if e['imm'] is not None:
                continue
            nxt = e['stage'] + 1
            if (nxt >= 3 and self.violent_used >= Q['violent_cap']) or \
                    (nxt == 4 and e['target'] == 'chief' and self.chief_attacked):
                e['quiet'] += 1; S['ember_held_by_cap'] += 1
                continue
            if self.r2.random() < self.esc_prob(e):
                e['imm'] = nxt; S['sign_imminent'] += 1
                if nxt >= 3: self.violent_used += 1
                if nxt == 4 and e['target'] == 'chief': self.chief_attacked = True
                self.react_imminent(e)
            else:
                e['quiet'] += 1

    def react_imminent(self, e):
        st = e['imm']
        e['blocked'] = False
        if st == 3 and not self.armory_asked:  # 무기고 통제: 첫 폭행 징후에서 한 번 묻는 관행
            self.armory_asked = True
            if Q['armory']:
                self.armory = True; self.stats['armory_control'] += 1
                self.rel['guard'] = clamp(self.rel['guard'] + 3, -100, 100)
                for c in ('tail', 'engine'):
                    self.rel[c] = clamp(self.rel[c] - 3, -100, 100)
        if st == 2:
            if e['cause'] == 'lack' or e['target'] in ('store', 'front', 'aide'):
                kind = 'poison'
            elif e['who'] == 'tail':
                kind = self.r2.choice(['coupling', 'heating'])
            elif e['who'] == 'engine':
                kind = 'boiler'
            else:
                kind = self.r2.choice(['heating', 'poison'])
            e['sab'] = kind
            if kind == 'boiler' and self.rel['engine'] >= 15:
                e['blocked'] = True; return  # 수석 기관사에게 맡긴다
        if self.wants_guard(st):
            self.post_guard(e)
            if e['sab'] == 'coupling' and self.guarded(e):
                self.rel['tail'] = clamp(self.rel['tail'] - 3, -100, 100)  # 창고칸 승강대에서 연결기를 보는 경비

    def victim_comm(self, target):
        if target in COMMS:
            return target
        return 'front' if target == 'store' else 'guard'

    def act(self, e):
        S = self.stats
        st = e['imm']; e['imm'] = None
        guarded = self.guarded(e)
        if e['blocked'] or (st <= 2 and guarded):  # 경비가 서 있으면 위협·사보타주는 막힌다
            e['blocked'] = False; e['quiet'] = 0
            S['blocked_act%d' % st] += 1
            if st >= 3: self.violent_used -= 1
            if st == 4 and e['target'] == 'chief': self.chief_attacked = False
            return
        e['stage'] = st; e['quiet'] = 0
        v = self.victim_comm(e['target'])
        if st == 1:
            S['act_threat'] += 1
            self.tension += Q['threat_tension']; self.fear += Q['threat_fear']
            self.rel[v] = clamp(self.rel[v] - 3, -100, 100)
        elif st == 2:
            k = e['sab']; S['act_sabotage'] += 1; S['sab_' + k] += 1
            if not Q['sab_on']:
                pass
            elif k == 'boiler':
                self.coal -= 4
                if self.r2.random() < 0.1: self.haul_once *= 0.5; S['boiler_damaged'] += 1
            elif k == 'coupling':
                self.coal -= 3; self.haul_once *= 0.7; self.fear += 5
            elif k == 'poison':
                self.food -= 5
                if self.r2.random() < 0.2:
                    self.injured += self.r2.choice([1, 2]); S['poison_sick'] += 1
            elif k == 'heating':
                self.base[v][0] -= 15
                self.scheduled.append((self.seg + 2, lambda v=v: self.base[v].__setitem__(0, self.base[v][0] + 15)))
            if self.dark == 'saint':  # 사람이 안 다친 사보타주도 수사한다
                self.open_case(e['who'], v, None, e, kind=k)
        elif st == 3:
            S['act_assault'] += 1
            if guarded: S['assault_halved'] += 1
            n = 1 if guarded else self.r2.choice([1, 2])
            self.tension += Q['assault_tension']
            pd = (Q['assault_death_armory'] if self.armory else Q['assault_death']) * (0.5 if guarded else 1)
            dead = 1 if self.r2.random() < pd else 0
            self.injured += n - dead
            if dead: self.train_death(1, v, violent=True)
            case = self.open_case(e['who'], v, Q['clock_death'] if dead else Q['clock_injury'], e, kind='assault')
            if guarded: self.caught(case)
        elif st == 4:
            S['act_assassination'] += 1
            self.tension += Q['assn_tension']
            self.kill_ember(e, 'ember_spent')
            if e['target'] == 'chief':
                S['chief_wounded'] += 1  # 첫 시도는 늘 부상(4.1 제동)
                case = self.open_case(e['who'], 'guard', Q['clock_injury'], None, kind='assn')
                if guarded: self.caught(case)
                return
            p = Q['assn_base'] - Q['assn_guard'] * guarded
            if e['target'] == 'guard' or (e['target'] == 'aide' and self.r2.random() < 1 / 3):
                p -= Q['assn_guardcap']
            if self.r2.random() < p:
                S['ember_assn_killed'] += 1
                self.train_death(1, v, violent=True)
                if e['target'] in COMMS or e['target'] == 'store':
                    self.succession(v)
                case = self.open_case(e['who'], v, Q['clock_death'], None, kind='assn')
            else:
                self.injured += 1
                case = self.open_case(e['who'], v, Q['clock_injury'], None, kind='assn')
            if guarded: self.caught(case)

    def caught(self, case):
        """경비가 선 자리의 폭행·암살: 범인이 '증거' 단계로 잡힌다(4.2, 2판)."""
        cul = next(s for s in case['sus'] if s['culprit'])
        cul['clues'] = max(cul['clues'], 2)
        self.stats['caught_by_guard'] += 1

    def starving_theft(self):
        """굶주림의 도둑질은 사다리 밖이다(4.3, 2판)."""
        S = self.stats
        m = self.m
        for c in COMMS:
            if m[c][1] <= Q['starve_line']:
                self.ration_streak[c] += 1
            else:
                self.ration_streak[c] = 0
            if self.ration_streak[c] == 2:
                S['sign_kiche'] += 1; S['theft_sign'] += 1  # 기척 하나가 먼저 온다(약속 아님)
            if self.ration_streak[c] >= 2 and self.r2.random() < Q['theft_p']:
                S['starve_theft'] += 1
                self.food -= self.r2.uniform(4, 6)
                self.base[c][1] += 5
                self.scheduled.append((self.seg + 2, lambda c=c: self.base[c].__setitem__(1, self.base[c][1] - 5)))

    def succession(self, c):
        """대표가 죽으면 측근이 대표가 된다. 관계가 회의 이하면 이념이 한 축 더 극단으로(S1a 4.2)."""
        self.stats['succession'] += 1
        if self.rel[c] <= -15:
            axes = [i for i in range(3) if self.ideo[c][i] != 0] or [0, 1, 2]
            i = self.r2.choice(axes)
            sgn = self.ideo[c][i] if self.ideo[c][i] else self.r2.choice([-1, 1])
            self.ideo[c][i] = 2 * (1 if sgn > 0 else -1)

    def train_death(self, n, comm, violent=False):
        if n <= 0:
            return
        ph, self._phase = self._phase, 'train'
        self.on_death(n, comm)
        self._phase = ph
        self.fresh_corpses += [comm] * n
        if violent:
            self.stats['violent_deaths'] += n

    # ---------------- 칸 안의 시신 (9.1, 9.2) ----------------
    def check_corpse(self, comm):
        S = self.stats
        if self.practice is None:
            self.practice = 'guard' if self.dark == 'tyrant' else 'medtech'
        S['train_corpses'] += 1
        if not Q['corpse_cost']:
            return
        if self.r2.random() < Q['vigil_p']:
            if self.dark == 'tyrant':
                self.rel[comm] = clamp(self.rel[comm] - 3, -100, 100)
            else:
                S['vigil_allowed'] += 1
                self.rel[comm] = clamp(self.rel[comm] + 4, -100, 100)
                self.base['guard'][3] += 1
                self.unchecked.append([comm, Q['vigil_guarded']])
                return
        if self.practice == 'guard':
            self.base['guard'][3] += 1; self.rel['guard'] = clamp(self.rel['guard'] - 2, -100, 100)
        elif self.practice == 'medtech':
            self.rel['medtech'] = clamp(self.rel['medtech'] - 3, -100, 100)
        else:
            self.rel[comm] = clamp(self.rel[comm] - 1, -100, 100); self.fear += 2
            if self.r2.random() < Q['car_miss']:
                self.unchecked.append([comm, Q['corpse_rise']])

    # ---------------- 수사와 처벌 (4.4) ----------------
    ACCESS = dict(boiler='engine', poison='front', assault='guard', assn='guard', order='guard', coupling='tail')

    def person(self, comm, culprit=False):
        """의심 점수(4.5, 2판): 판 중 합류 +2, 드나듦 +2, 구조민 +1, 사건 칸 +1, 원수 +1, 전에 벌받음 +1."""
        r2 = self.r2
        s = 0
        if comm == 'tail':
            s += 1 if r2.random() < 0.9 else 0                       # 꼬리칸 90명 중 80명이 구조민
            if self.stats['rescued'] and r2.random() < min(1.0, 2 * self.stats['rescued'] / 90 + (0 if culprit else 0.6)):
                s += 2                                                 # 판 중에 데려온 사람
        elif r2.random() < 0.34:
            s += 1                                                     # 다른 칸의 구조민(37/110)
        if comm in self.punished_comms and r2.random() < 0.5:
            s += 1
        return dict(comm=comm, culprit=culprit, susp=s, clues=0, acq=False)

    def open_case(self, culprit, victim, clock, ember, own=False, kind='assault'):
        S = self.stats
        r2 = self.r2
        access = self.ACCESS.get(kind)
        cands = [self.person(culprit, culprit=True), self.person('tail'), self.person(victim)]
        if access: cands.append(self.person(access))
        for a, b in RIVALS:
            if victim in (a, b):
                cands.append(self.person(b if victim == a else a)); break
        for p in cands:
            if access and p['comm'] == access: p['susp'] += 2
            if p['comm'] == victim or (r2.random() < 0.3): p['susp'] += 1
            if rivals(p['comm'], victim): p['susp'] += 1
        cul, pool = cands[0], cands[1:]
        pool.sort(key=lambda s: -(s['susp'] + r2.random() * 0.9))
        if not Q['crowd']:
            clock = None
        case = dict(crowd=clock is not None, culprit=culprit, victim=victim, clock=clock, status='open', protects=0,
                    promised=False, promise_used=False, trial_ext=False, opened=self.seg, ember=ember, own=own,
                    sus=[cul] + pool[:2])
        self.cases.append(case)
        S['cases'] += 1
        if cul['susp'] >= max(s['susp'] for s in pool[:2]):
            S['culprit_top_suspect'] += 1
        return case

    def eligible(self, case):
        return [s for s in case['sus'] if not s['acq']] or case['sus']

    def top_by_clues(self, case):
        return max(self.eligible(case), key=lambda s: (s['clues'], s['susp'], self.r2.random()))

    def top_by_susp(self, case):
        return max(self.eligible(case), key=lambda s: (s['susp'], s['clues'], self.r2.random()))

    def investigate(self):
        S = self.stats
        for case in list(self.cases):
            if case['status'] != 'open':
                continue
            S['investigate_segments'] += 1
            p_true = min(Q['clue_cap'], Q['clue_true'] + 0.15 * (self.rel['guard'] >= 15)
                         + 0.15 * ('patrol' in self.passed) + 0.10 * (self.fear >= 20))
            p_false = (1 - p_true) * (Q['false_mult_fear'] if self.fear >= 60 else Q['false_mult'])
            roll = self.r2.random()
            if roll < p_true:
                s = next(s for s in case['sus'] if s['culprit'])
                s['clues'] += 1; s['susp'] += 1; S['clue_true'] += 1
            elif roll < p_true + p_false:
                s = self.r2.choice([s for s in case['sus'] if not s['culprit']])
                s['clues'] += 1; s['susp'] += 1; S['clue_false'] += 1
            d = self.dark
            top = self.top_by_clues(case)
            if d == 'tyrant':
                self.summary(case)
            elif self.ml:
                self.guard_trial(case)
            elif top['clues'] >= 2:
                self.send_trial(case)
            elif d == 'saint' and case['clock'] is not None and case['clock'] <= 1 and top['clues'] >= 1:
                self.send_trial(case)
            elif self.seg - case['opened'] >= Q['cold_case']:
                case['status'] = 'closed'; S['cold_cases'] += 1

    def send_trial(self, case):
        case['status'] = 'trial'
        if case['clock'] is not None and not case['trial_ext']:  # 시계를 멈추지 않고 한 번 +1구간(2판)
            case['trial_ext'] = True; case['clock'] += 1
        self.stats['sent_trial'] += 1

    def guard_trial(self, case):
        """계엄 중 경비대 재판: 증거면 유죄, 정황 60%, 소문 30%(5.3, 2판)."""
        S = self.stats
        S['guard_trials'] += 1
        dfd = self.top_by_clues(case)
        p = 1.0 if dfd['clues'] >= 2 else 0.6 if dfd['clues'] == 1 else 0.3
        if self.r2.random() < p:
            self.punish(case, dfd, 'confine')
        else:
            dfd['acq'] = True

    def summary(self, case):
        S = self.stats
        top = self.top_by_clues(case)
        p_mis = 0.0 if top['clues'] >= 2 else 0.4 if top['clues'] == 1 else 0.7
        if self.r2.random() < p_mis:
            person = self.r2.choice([s for s in case['sus'] if not s['culprit']])
        else:
            person = next(s for s in case['sus'] if s['culprit'])
        S['summary'] += 1
        self.fear += 5
        for c in COMMS:
            if c != 'guard':
                self.rel[c] = clamp(self.rel[c] - 2, -100, 100)
        self.punish(case, person, 'exile' if self.dark == 'tyrant' else 'confine')

    def punish(self, case, person, how):
        """벌은 긴장을 내리지 않는다. 군중 시계를 끝낼 뿐이다(4.4, 2판)."""
        S = self.stats
        c = person['comm']
        case['status'] = 'closed'
        S['punished'] += 1
        self.punished_comms.append(c)
        if how == 'exile':  # 하차 명령
            S['exiles'] += 1
            self.rel[c] = clamp(self.rel[c] - 8, -100, 100); self.fear += 5; self.pop[c] -= 1
        elif how == 'confine':
            S['confined'] += 1
            for k in range(4):
                self.scheduled.append((self.seg + 1 + k, lambda: self.base['guard'].__setitem__(3, self.base['guard'][3] + 2)))
        else:  # 배급을 끊는다
            S['ration_cut'] += 1
            self.rel[c] = clamp(self.rel[c] - 3, -100, 100)
        if person['culprit']:
            S['solved'] += 1
            if case['ember'] is not None:
                self.kill_ember(case['ember'], 'ember_punished')
            if case['own'] and self.r2.random() < Q['order_names_chief']:
                self.expose_order(case['victim'])
        else:
            S['misjudged'] += 1
            self.innocents.append([c, self.seg])
            self.new_ember(c, 'guard', 'misjudged')

    def hold_trial(self, case):
        S = self.stats
        S['trials'] += 1
        dfd = self.top_by_clues(case)
        ev = 2 if dfd['clues'] >= 2 else 0 if dfd['clues'] == 1 else -2
        yes = 0
        for c in COMMS:
            score = ev + (1 if c == case['victim'] else 0) - (2 if c == dfd['comm'] else 0) + band(self.rel[c])
            y, u, n = self.split(score)
            s = SEATS[c]
            yy = round(s * y); nn = round(s * n); uu = s - yy - nn
            p = clamp(0.5 + 0.1 * score, 0.2, 0.8)
            yes += yy + sum(1 for _ in range(uu) if self.r2.random() < p)
        case['promised'] = False
        if yes >= 51:
            S['guilty'] += 1
            self.punish(case, dfd, 'ration_cut' if self.dark == 'saint' else 'confine')
        else:
            S['acquitted'] += 1
            dfd['acq'] = True
            self.rel[dfd['comm']] = clamp(self.rel[dfd['comm']] + 3, -100, 100)
            case['status'] = 'open'
            if case['clock'] is not None:
                case['clock'] = 1  # 무죄면 군중은 다음 구간에 온다

    # ---------------- 군중 (4.5) ----------------
    def crowd_card(self, case):
        S = self.stats
        d = self.dark
        S['crowd_cards'] += 1
        if d == 'tyrant' or (d in ('caretaker', 'schemer_plus') and self.tension > Q['scapegoat_tension']):
            self.scapegoat(case)
        elif not case['promise_used'] and not self.ml:  # 재판을 약속한다: 시계 +1, 사건 하나에 한 번
            case['promise_used'] = True; case['promised'] = True
            case['status'] = 'trial'; case['clock'] += 1
            S['promised_trial'] += 1
        else:
            self.protect(case)

    def protect(self, case):
        S = self.stats
        S['protected'] += 1
        if case['protects'] >= 1 and self.r2.random() < Q['protect_hurt']:
            self.injured += 1; S['guard_hurt_protecting'] += 1
        case['protects'] += 1
        case['clock'] = 1
        self.base['guard'][3] += 5; self.fear += 3
        v = case['victim']
        self.rel[v] = clamp(self.rel[v] - 5, -100, 100)
        if case['status'] == 'open' and self.top_by_clues(case)['clues'] >= 1 and not self.ml:
            self.send_trial(case)  # 정황 이상인 용의자가 있으면 재판에 넘긴다

    def scapegoat(self, case, allowed=False):
        """내준다(또는 막지 않은 린치). 긴장은 내리지 않고 군중 시계만 끝난다(2판)."""
        S = self.stats
        person = self.top_by_susp(case)
        c = person['comm']
        S['lynch_allowed' if allowed else 'scapegoats'] += 1
        S['lynch_events'] += 1
        if allowed: self.fear += 5
        if self.r2.random() < Q['scapegoat_death']:
            self.train_death(1, c, violent=True); S['lynch_deaths'] += 1
        else:
            self.injured += 1
        self.rel[c] = clamp(self.rel[c] - 10, -100, 100)
        self.offend(c)
        case['status'] = 'closed'
        self.punished_comms.append(c)
        if person['culprit']:
            S['scapegoat_guilty'] += 1
            if case['ember'] is not None:
                self.kill_ember(case['ember'], 'ember_punished')
        else:
            S['scapegoat_innocent'] += 1
            self.innocents.append([c, self.seg])
        self.new_ember(c, 'guard', 'scapegoat')

    # ---------------- 암살 명령 (4.6, 4.7) ----------------
    def can_order(self):
        return (self.dark in ('tyrant', 'schemer_plus') and self.order is None
                and self.stats['assn_ordered'] < Q['assn_cap'] and self.seg < P['segments'])

    def order_assassination(self, target, why, guard_mod=-0.10):
        if not self.can_order():
            return False
        if self.rel['guard'] >= 15:
            exe, mod = 'guard', 0.10
        else:
            enemy = next((b if a == target else a for a, b in RIVALS if target in (a, b)), None)
            exe, mod = (enemy, 0.10) if enemy else (target, -0.10)
        method = ('stop', 0.10, 0.30) if self.dark == 'tyrant' else ('accident', -0.10, 0.20)
        self.order = dict(target=target, exe=exe, exe_mod=mod, method=method, guard_mod=guard_mod, why=why)
        self.stats['assn_ordered'] += 1
        self.stats['assn_why_' + why] += 1
        return True

    def execute_order(self):
        S = self.stats
        o, self.order = self.order, None
        t, exe = o['target'], o['exe']
        name, mmod, p_exp = o['method']
        p = clamp(Q['order_base'] + o['exe_mod'] + mmod + o['guard_mod'], 0.15, 0.85)
        if o['why'] == 'silence' and t in self.executors:
            self.executors.remove(t)  # 입을 막으면 새 실행자가 또 약점을 쥔다
        self.executors.append(exe)
        if self.r2.random() < p:
            S['assn_succeeded'] += 1
            if name == 'stop':
                ph, self._phase = self._phase, 'stop'
                self.on_death(1, t); self._phase = ph
                S['violent_deaths'] += 1
                self.rel[t] = clamp(self.rel[t] - 5, -100, 100)  # 죽을 곳에 보냈다: 그 칸이 알아챈다(4.7)
            else:
                self.train_death(1, t, violent=True)
            if o['why'] != 'silence':
                self.succession(t)
                self.rel[t] = clamp(self.rel[t] - 10, -100, 100)
                self.fervor[t] = min(3, self.fervor[t] + 1)
                if Q['leaderless']:
                    self.leaderless.add(t)
            case = self.open_case(exe, t, Q['clock_death'], None, own=True, kind='order')
            if self.r2.random() < p_exp:
                self.expose_order(t)
            if self.dark == 'tyrant':  # 덮는다
                case['status'] = 'closed'; S['covered_up'] += 1
                self.offend(t); self.offend(t)
            else:  # 누명: 다른 용의자에게 단서 하나, 실행자의 불씨가 커진다
                inn = max((s for s in case['sus'] if not s['culprit']), key=lambda s: s['susp'])
                inn['clues'] += 1; inn['susp'] += 1
                S['frames'] += 1
                self.new_ember(exe, 'chief', 'executor', p=1.0)
        else:
            S['assn_failed'] += 1
            self.injured += 1
            self.open_case(exe, t, Q['clock_injury'], None, own=True, kind='order')
            if self.r2.random() < Q['order_exposed_fail_caught'] and self.r2.random() < Q['order_names_chief']:
                self.expose_order(t)

    def expose_order(self, target):
        S = self.stats
        if S['_exposed_now'] == self.seg:
            return
        S['_exposed_now'] = self.seg
        S['assn_exposed'] += 1
        self.trust -= 20
        for c in COMMS:
            self.offend(c)
        self.offend(target); self.offend(target)

    # ---------------- 탄압과 계엄 (5.1, 5.3) ----------------
    def disperse(self, c):
        S = self.stats
        if self.rel['guard'] <= -15 and self.r2.random() < Q['guard_refuse']:
            S['guard_refused'] += 1
            return
        first = self.dispersed[c] == 0
        self.dispersed[c] += 1
        S['dispersals'] += 1
        if Q['repress_extinguish']:
            for e in list(self.embers):
                if e['who'] == c and e['imm'] is None:
                    self.kill_ember(e, 'ember_repressed')
        self.repressed_until[c] = self.seg + 6
        if first:
            self.fervor[c] = 0
        else:
            self.fervor[c] = max(0, self.fervor[c] - 1)
            self.new_ember(c, 'guard', 'repression')
        self.rel[c] = clamp(self.rel[c] - 15, -100, 100)
        self.offend(c)
        self.fear += 10; self.tension += Q['disperse_tension']
        if S['dispersals'] % 3 == 0:
            for o in COMMS:
                self.offend(o)

    def ml_ok(self):
        return self.rel['guard'] >= Q['ml_rel'] and self.grudge['guard'] <= Q['ml_grudge_max']

    def ep_expire(self):
        S = self.stats
        self.ep_on = False
        self.passed.discard('emergency_powers')
        self.repealed_at['emergency_powers'] = self.session
        if self.dark == 'tyrant':
            if self.ml_ok():
                self.declare_ml('extend'); return
            S['ml_locked'] += 1
        S['ep_returned'] += 1
        self.trust += 5
        for law in self.ep_decrees:  # 추인 안 된 포고는 사라진다
            if law in self.passed:
                self.silent_remove(law)
        self.ep_decrees = []

    def silent_remove(self, law):
        self.passed.discard(law)
        for c, delta in LAWS[law]['mats'].items():
            for i in range(4):
                self.base[c][i] -= delta[i]
        if law in CORPSE:
            self.corpse_issue = True

    # ---------------- 내전 직전과 내전 (5.5, 3판) ----------------
    ML_DOOR_MEANS = dict(extend=5, council=2, brink=4, war=4, captain=0)

    def declare_ml(self, door='extend', pair=()):
        """계엄으로 가는 문 넷(5.5). 들어선 뒤의 규칙은 5.3 그대로다."""
        S = self.stats
        self.ml = True; self.ml_start = self.seg; self.pre_ml_trust = self.trust
        self.ep_on = False; self.ep_decrees = []
        self.passed.discard('emergency_powers')
        S['ml_declared'] += 1; S['ml_door_' + door] += 1; S['ml_means'] += self.ML_DOOR_MEANS[door]
        if door == 'extend':
            for c in COMMS:
                if c != 'guard':
                    self.offend(c)
            self.tension += 10
        elif door == 'council':
            self.tension += 3
        else:  # 내전 직전·내전에서 선포, 경비대장의 계엄
            for c in pair:
                self.offend(c)
            for c in COMMS:
                if c not in pair:
                    self.rel[c] = clamp(self.rel[c] + (5 if door == 'brink' else 3), -100, 100)
            self.tension += 5
            if door == 'captain':
                self.trust -= 10
                self.coup_line_now = 14  # 쿠데타 경고 문턱이 한 단계 높다(중립 이하)
        self.ration['guard'] = min(4, self.ration['guard'] + 1)
        self.ml_floor = self.ration['guard']

    def brink_tick(self):
        """정산: 내전 직전이 시작되는지, 시계가 다 됐는지."""
        S = self.stats
        if self.brink:
            b = self.brink
            if b['start'] < self.seg:
                b['clock'] -= 1
            if b['clock'] <= 0:
                if b.get('cond'):
                    S['truce_failed'] += 1
                    for kind in (b['cond'][c] for c in b['pair'] if c not in b['kept']):
                        S['truce_miss_' + kind] += 1
                self.brink = None
                self.start_war(b['pair'])
            return
        if self.war or self.ml or self.wars_n >= Q['war_max'] or self.brinks_n >= Q['brink_max']:
            return
        for a, b in RIVALS:
            if self.fervor[a] < 2 or self.fervor[b] < 2:
                continue
            sab = any(e['stage'] >= 2 and {e['who'], e['target']} == {a, b} for e in self.embers)
            if sab or self.tension >= Q['brink_tension']:
                clock = Q['brink_clock'] - (1 if (self.dispersed[a] or self.dispersed[b]) else 0)
                self.brink = dict(pair=(a, b), clock=clock, start=self.seg, k=0, sep=False, pledge=False)
                self.brinks_n += 1
                S['brinks'] += 1; S['brink_any'] = 1; S['brink_' + a + '_' + b] += 1
                return

    def brink_card(self):
        S = self.stats
        b = self.brink
        a, c = b['pair']
        b['k'] += 1
        self.tension += Q['brink_seg_tension']
        S['sign_brink'] += 1
        d = self.dark
        guard_ok = self.rel['guard'] > -15 and 'guard' not in b['pair']
        bigger, smaller = (a, c) if SEATS[a] >= SEATS[c] else (c, a)
        if d == 'tyrant' and not self.ml and guard_ok:
            self.declare_ml('brink', b['pair']); S['brink_end_ml'] += 1
            for x in b['pair']: self.fervor[x] = min(self.fervor[x], 1)
            self.brink = None; return
        if d in ('tyrant', 'schemer_plus'):
            self.take_side(bigger, smaller); S['brink_end_side'] += 1
            self.brink = None; return
        if b.get('cond'):  # 서약이 통과했다: 남은 조건을 지킨다(5.5, 3라운드)
            if self.truce_keep(b):
                return
            if Q['truce_sep'] and not b['sep'] and b['clock'] <= 1:
                b['sep'] = True; b['clock'] += 1; S['brink_separate'] += 1
                for x in b['pair']:
                    self.rel[x] = clamp(self.rel[x] - 5, -100, 100)
        elif not b['pledge'] and self.trust >= 40:  # 한 탁자에 앉힌다: 비상 소집으로 '휴전 서약'(가정)
            b['pledge'] = True
            self.trust -= Q['pledge_cost']; S['pledge_votes'] += 1
            if self.pledge_vote(b['pair']):
                if not Q['truce_cond']:  # 2라운드: 통과만으로 멈춘다
                    S['brink_end_peace'] += 1
                    for x in b['pair']:
                        self.fervor[x] = max(0, self.fervor[x] - 1)
                        self.promises.append((x, self.seg + 3, self.r2.choice(['lever', 'medicine', 'luxury', 'target'])))
                    self.brink = None; return
                b['cond'] = {x: self.r2.choice(['lever', 'medicine', 'luxury', 'target']) for x in b['pair']}
                b['kept'] = set()
                for k in b['cond'].values():
                    S['truce_cond_' + k] += 1
                if self.truce_keep(b):
                    return
        elif not b['sep']:  # 떼어 놓는다
            b['sep'] = True; b['clock'] += 1; S['brink_separate'] += 1
            for x in b['pair']:
                self.rel[x] = clamp(self.rel[x] - 5, -100, 100)
        if self.brink and b['k'] == 2 and not self.ml and self.r2.random() < Q['ai_ml_request']:
            S['ai_ml_request'] += 1
            if self.ml_request_vote(b['pair']):
                S['brink_end_ml'] += 1
                self.declare_ml('council', b['pair'])
                for x in b['pair']: self.fervor[x] = min(self.fervor[x], 1)
                self.brink = None

    def truce_keep(self, b):
        """서약의 두 조건을 S1a 약속 이행(3.2)과 같은 방식으로 지키려 한다. 둘 다 지키면 시계가 멈춘다.
        'target'(다음 정차를 그 집단 뜻대로)은 한 번만 굴린다. 나머지는 물자가 될 때까지 구간마다 다시 본다."""
        S = self.stats
        for c, kind in b['cond'].items():
            if c in b['kept']:
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
            elif kind == 'target' and not b.get('target_rolled'):
                b['target_rolled'] = True
                ok = self.r2.random() < P['target_keep']
            if ok:
                b['kept'].add(c)
                self.trust += 4; self.rel[c] = clamp(self.rel[c] + 5, -100, 100)
                S['truce_cond_kept'] += 1
        if len(b['kept']) == len(b['cond']):
            S['brink_end_peace'] += 1; S['truce_kept'] += 1
            for x in b['pair']:
                self.fervor[x] = max(0, self.fervor[x] - 1)
            self.brink = None
            return True
        return False

    def vote_yes(self, scores, need):
        yes = 0
        for cc in COMMS:
            y, u, n = self.split(scores[cc])
            s = SEATS[cc]
            yy = round(s * y); nn = round(s * n); uu = s - yy - nn
            p = clamp(0.5 + 0.1 * scores[cc], 0.2, 0.8)
            yes += yy + sum(1 for _ in range(uu) if self.r2.random() < p)
        return yes >= need

    def pledge_vote(self, pair):
        sc = {}
        for x in COMMS:
            s = band(self.rel[x]) + (0 if x in pair else 2)  # 끼지 않은 칸은 평화를 바란다(가정)
            if self.grudge[x] >= P['hostile_grudge']:
                s = min(s, -3)
            elif self.grudge[x] >= 1:
                s -= 1
            sc[x] = s
        ok = self.vote_yes(sc, 51)
        self.stats['pledge_passed'] += ok
        return ok

    def ml_request_vote(self, pair):
        lean = 1 if self.dark in ('tyrant', 'schemer_plus') else -1  # 열차장이 표를 모으거나 막는다
        sc = {x: self.ideo[x][1] + (-1 if x in pair else 1) + (1 if x == 'guard' else 0) + lean for x in COMMS}
        ok = self.vote_yes(sc, 67)
        self.stats['ai_ml_passed'] += ok
        return ok

    def take_side(self, win, lose):
        """한쪽 편을 든다: 고른 쪽에 지지, 다른 쪽에 지도부 근신(5.1)."""
        S = self.stats
        S['mass_arrest'] += 1
        self.rel[win] = clamp(self.rel[win] + Q['support_rel'], -100, 100)
        self.fervor[win] = max(0, self.fervor[win] - 1)
        self.offend(lose); self.offend(lose)
        self.tension += 10; self.fear += 10
        if self.r2.random() < 0.5:  # 진 쪽 불씨가 바로 '폭행 임박'
            e = next((x for x in self.embers if x['who'] == lose and x['imm'] is None), None)
            if e is None and len(self.embers) < Q['ember_max']:
                self.eid += 1
                e = dict(id=self.eid, who=lose, target=win, cause='side', stage=2, imm=None, quiet=0,
                         guard_until=-1, sab=None, blocked=False)
                self.embers.append(e); S['embers'] += 1; S['ember_side'] += 1
            if e is not None and self.violent_used < Q['violent_cap']:
                e['stage'] = 2; e['imm'] = 3; self.violent_used += 1
                S['sign_imminent'] += 1; S['side_assault_imminent'] += 1
                self.react_imminent(e)

    def start_war(self, pair):
        S = self.stats
        self.war = dict(pair=pair, segs=0, end_next=None)
        self.wars_n += 1
        S['wars'] += 1; S['war_any'] = 1

    def war_card(self):
        S = self.stats
        w = self.war
        a, c = w['pair']
        bigger, smaller = (a, c) if SEATS[a] >= SEATS[c] else (c, a)
        if w['end_next'] == 'ml':  # 진압: 싸움이 끝나지만 1~2명이 더 죽는다
            n = self.r2.choice([1, 2])
            for _ in range(n):
                self.train_death(1, self.r2.choice(w['pair'])); S['war_deaths'] += 1
            self.war = None; S['war_end_ml'] += 1; return
        if w['end_next'] == 'help':
            win, lose = w['help']
            self.war_loss(lose, Q['war_help_trust']); S['war_end_help'] += 1
            self.war = None; return
        # 싸움: 1명이 죽고 2명이 다친다. 정차 산출 −50%, 긴장 +8
        self.train_death(1, self.r2.choice(w['pair'])); S['war_deaths'] += 1
        self.injured += 2
        self.haul_once *= 0.5
        self.tension += 8
        w['segs'] += 1
        S['war_segments'] += 1
        d = self.dark
        g = self.rel['guard']
        locked = g <= -40
        if d == 'tyrant' and not self.ml and g > -40 and 'guard' not in w['pair']:
            self.declare_ml('war', w['pair']); w['end_next'] = 'ml'; return
        if d in ('tyrant', 'schemer_plus') and not locked:
            w['end_next'] = 'help'; w['help'] = (bigger, smaller); S['war_help'] += 1; return
        if d in ('saint', 'caretaker') and self.trust >= 60:
            S['war_truce_try'] += 1
            if self.r2.random() < 0.5:
                S['war_end_truce'] += 1; self.war = None; return
        else:  # 손 놓는다
            S['war_hands_off'] += 1
            if (self.captain_ambitious and g >= 15 and not self.ml and 'guard' not in w['pair']
                    and self.r2.random() < 0.4):
                self.declare_ml('captain', w['pair']); w['end_next'] = 'ml'; return
        if w['segs'] >= 2:  # 한쪽이 이긴다(의석 비율로 주사위)
            win = a if self.r2.random() < SEATS[a] / (SEATS[a] + SEATS[c]) else c
            self.war_loss(c if win == a else a, -15); S['war_end_fought'] += 1
            self.war = None

    def war_loss(self, lose, trust):
        S = self.stats
        if self.r2.random() < 0.5:
            S['war_leader_killed'] += 1
            self.train_death(1, lose); S['war_deaths'] += 1
            self.succession(lose)
        self.grudge[lose] = 3; self.last_offense[lose] = self.session
        self.trust += trust

    def lift_ml(self):
        self.ml = False; self.coup_warn = None
        self.stats['ml_lifted'] += 1
        self.trust = self.pre_ml_trust - 15
        self.stats['ml_len'] += self.seg - self.ml_start

    def council_options(self):
        cool = P['repeal_cool']
        options = [(l, False) for l, v in LAWS.items() if l not in self.passed and v['open'](self)
                   and not (l in CORPSE and self.corpse) and self.session - self.repealed_at.get(l, -99) > cool]
        if P['repeal'] and self.policy not in ('passive', 'idealist'):
            options += [(l, True) for l in self.passed if self.session - self.passed_at.get(l, 0) >= cool]
        crisis = [k for k, lim in (('coal', P['crisis_line']), ('food', P['crisis_line'])) if getattr(self, k) < lim]
        if self.corpse_issue: crisis.append('corpse')
        if self.med <= 3 and self.injured >= 4: crisis.append('med')
        forced = [o for o in options if (set(LAWS[o[0]]['crisis']) & set(crisis) if not o[1]
                                         else set(self.drains(o[0])) & set(crisis))] if P['forced_agenda'] else []
        return (forced or options), bool(forced)

    def decree(self):
        """표결 없는 포고: 법 하나를 통과시키거나 폐지한다."""
        options, forced = self.council_options()
        if forced:
            self.stats['forced'] += 1; self.stats['forced_passed'] += 1  # 포고는 표결 없이 통과한다
        if self.ml:  # 충성은 쓰면 준다: 포고마다 경비대 관계 −5(2판)
            self.rel['guard'] = clamp(self.rel['guard'] + Q['decree_guard'], -100, 100)
        options = [o for o in options if o[0] not in ('emergency_powers', 'guided_voting', 'secret_ballot')]
        if not options:
            return None
        tight = clamp((P['plan_line'] - min(self.coal, self.food)) / 60, 0.5, 1.5)

        def val(o):
            law, rep = o
            worth = self.repeal_worth(law) if rep else self.law_worth(law)
            ease = sum(self.stance(c, law, rep)[0] * SEATS[c] for c in COMMS) / 10
            return worth * tight + ease * 0.5 + self.r2.random() * 0.5
        law, repeal = max(options, key=val)
        S = self.stats
        S['decrees'] += 1
        if repeal:
            self.repeal_law(law); return None
        self.passed.add(law); self.passed_at[law] = self.session
        self.apply_law(law)
        S['passed'] += 1; S['pass_' + law] += 1
        if law in HARSH:
            S['harsh_passed'] += 1; S['harsh_decreed'] += 1
            if forced: S['harsh_forced'] += 1
        if law in IDEAL: S['ideal_passed'] += 1
        return law

    def session_bookkeeping(self):
        self.session += 1
        if self.session % 2 == 0: self.secrets += 1
        for c in COMMS:
            if self.grudge[c] and self.session - self.last_offense[c] >= P['grudge_decay']:
                self.grudge[c] -= 1; self.last_offense[c] = self.session
        self.stats['hostile_blocs'] += sum(1 for c in COMMS if self.grudge[c] >= P['hostile_grudge'])

    def council(self):
        if not self.s1b:
            return super().council()
        S = self.stats
        if self.war:  # 내전 중엔 회기가 열리지 않는다
            S['council_skipped_war'] += 1
            return
        if self.ml:  # 의회 대신 포고
            self.session_bookkeeping(); self.decree()
            return
        trial = next((c for c in self.cases if c['status'] == 'trial'), None)
        if trial:
            self.session += 1
            _, forced = self.council_options()
            self.session -= 1
            if Q['trial_defer'] and forced:
                S['trial_deferred'] += 1
                if trial['promised']:  # 수사 약속을 어겼다
                    S['promise_trial_broken'] += 1
                    self.break_promise((trial['victim'], self.seg, 'trial'))
                    trial['promised'] = False
            elif Q['trial_slot']:
                self.session_bookkeeping()
                S['law_slot_lost_to_trial'] += 1
                self.hold_trial(trial)
                return
            else:  # (시험) 재판이 법 안건 자리를 먹지 않는다
                self.hold_trial(trial)
        before = (S['proposals'], S['failed'], S['forced'], S['harsh_passed'])
        self._last_vote = None
        super().council()
        S = self.stats  # law_value가 stats를 복사본으로 바꿔 끼운다
        if S['proposals'] > before[0] and self._last_vote:
            law, repeal, blocs = self._last_vote
            failed = S['failed'] > before[1]
            forced = S['forced'] > before[2]
            self.leaderless.clear()
            ok = not failed
            for a, b in RIVALS:
                sa = 1 if blocs[a]['yes'] > blocs[a]['no'] else -1 if blocs[a]['no'] > blocs[a]['yes'] else 0
                sb = 1 if blocs[b]['yes'] > blocs[b]['no'] else -1 if blocs[b]['no'] > blocs[b]['yes'] else 0
                if sa * sb == -1:
                    loser = a if (sa == 1) != ok else b
                    winner = b if loser == a else a
                    self.new_ember(loser, winner, 'rival', p=Q['rival_p'])
            if forced and S['harsh_passed'] > before[3]:
                S['harsh_forced'] += 1  # 법 요구로 통과시킨 가혹 법은 수단에서 뺀다(10.2, 2판)
            if failed and forced and Q['assn_on_fail']:
                cands = [c for c in COMMS if blocs[c]['no'] > 0 and (self.grudge[c] >= 2 or self.rel[c] <= -40)]
                if cands:
                    self.order_assassination(max(cands, key=lambda c: (blocs[c]['no'], SEATS[c])), 'crisis_fail')
        if 'emergency_powers' in self.passed and not self.ep_on and not self.ml:
            self.ep_on = True; self.ep_left = Q['ep_len']; self.ep_decrees = []
            S['ep_passed'] += 1

    def play(self):
        super().play()
        if self.s1b:
            if self.ml:
                self.stats['ml_len'] += self.seg - self.ml_start + 1
            S = self.stats
            S['harsh_chosen'] = S['harsh_passed'] - S['harsh_forced']
            S['means'] = sum(w * S[k] for k, w in MEANS.items())
            S['violence'] = S['act_assault'] + S['act_assassination'] + S['lynch_events'] + S['assn_succeeded'] \
                + S['assn_failed']
            S['signs'] = S['sign_kiche'] + S['sign_imminent']
        return self


# ---------------- 집계 ----------------
def run_policy(policy, n, places, s1b=True):
    ends = Counter(); agg = defaultdict(float); means = []
    tone = Counter()
    for i in range(n):
        run = DarkRun(1000 + i, policy, places, s1b).play()
        ends[run.end] += 1
        for k, v in run.stats.items():
            if not k.startswith('_'):
                agg[k] += v
        agg['end_trust'] += run.trust
        agg['segments_played'] += run.seg
        if s1b:
            means.append(run.stats['means'])
            dark = run.stats['means'] >= 8
            saved = run.end == 'complete' and run.stats['deaths'] <= 6
            tone[('dark' if dark else 'clean') + '/' + ('saved' if saved else 'lost')] += 1
    return ends, agg, means, tone


def pct(ends, k, n):
    return ends.get(k, 0) / n


def report(policy, n, places):
    ends, agg, means, tone = run_policy(policy, n, places)
    a = lambda k: agg[k] / n
    out = dict(policy=policy, complete=pct(ends, 'complete', n), stranded=pct(ends, 'stranded', n),
               ousted=pct(ends, 'ousted', n), revolt=pct(ends, 'revolt', n), coup=pct(ends, 'coup', n),
               signs=a('signs'), kiche=a('sign_kiche'), imminent=a('sign_imminent'), violence=a('violence'),
               violent_deaths=a('violent_deaths'), means=sum(means) / n, dark8=sum(1 for x in means if x >= 8) / n,
               ml_rate=sum(1 for _ in range(1)) and agg['ml_declared'] / n)
    print(f'\n## {policy} (S1b, {n}판)')
    print('끝:', ', '.join(f'{k} {v / n:.0%}' for k, v in ends.most_common()))
    groups = [
        ('징후', ['signs', 'sign_kiche', 'sign_imminent', 'embers', 'ember_trigger', 'ember_capped', 'ember_curfew_blocked',
                 'ember_fervor', 'ember_grudge', 'ember_lack', 'ember_leash', 'ember_rival', 'ember_misjudged',
                 'ember_scapegoat', 'ember_repression', 'ember_executor', 'ember_floor', 'floor_converted', 'guard_posted',
                 'guard_unavailable']),
        ('불씨 끝', ['ember_resolved', 'ember_quiet', 'ember_punished', 'ember_repressed', 'ember_spent', 'ember_held_by_cap']),
        ('폭력', ['act_threat', 'act_sabotage', 'sab_boiler', 'sab_coupling', 'sab_poison', 'poison_sick', 'starve_theft', 'theft_sign', 'sab_heating', 'act_assault',
                 'act_assassination', 'chief_wounded', 'ember_assn_killed', 'blocked_act1', 'blocked_act2',
                 'blocked_act3', 'blocked_act4', 'assault_halved', 'caught_by_guard', 'armory_control', 'violence', 'violent_deaths', 'lynch_events', 'lynch_deaths']),
        ('수사', ['cases', 'clue_true', 'clue_false', 'sent_trial', 'trials', 'guilty', 'acquitted', 'trial_deferred',
                 'law_slot_lost_to_trial', 'summary', 'solved', 'misjudged', 'scapegoats', 'scapegoat_innocent',
                 'truth_revealed', 'crowd_cards', 'protected', 'promised_trial', 'promise_trial_broken', 'cold_cases',
                 'guard_trials', 'culprit_top_suspect', 'deserters',
                 'exiles', 'confined', 'ration_cut']),
        ('시신', ['train_corpses', 'vigil_allowed', 'corpse_rise', 'bites_found', 'bite_outbreak', 'deaths']),
        ('탄압·계엄', ['dispersals', 'guard_refused', 'ep_passed', 'ep_returned', 'ml_locked', 'ml_declared', 'ml_len',
                    'decrees', 'harsh_decreed', 'coup_warning']),
        ('내전', ['brink_any', 'brinks', 'brink_tail_front', 'brink_engine_medtech', 'brink_guard_tail', 'brink_end_peace',
                 'brink_end_side', 'brink_end_ml', 'brink_separate', 'pledge_votes', 'pledge_passed', 'ai_ml_request',
                 'ai_ml_passed', 'war_any', 'war_segments', 'war_deaths', 'war_end_ml', 'war_end_help',
                 'war_end_truce', 'war_end_fought', 'war_hands_off', 'war_leader_killed', 'council_skipped_war',
                 'ml_door_extend', 'ml_door_council', 'ml_door_brink', 'ml_door_war', 'ml_door_captain',
                 'truce_cond_kept', 'truce_kept', 'truce_failed', 'truce_miss_lever', 'truce_miss_medicine',
                 'truce_miss_luxury', 'truce_miss_target']),
        ('암살 명령', ['assn_ordered', 'assn_why_hostile', 'assn_why_silence', 'assn_why_crisis_fail', 'assn_succeeded', 'assn_failed', 'assn_exposed', 'frames', 'covered_up',
                    'executor_blackmail', 'succession']),
        ('S1a', ['passed', 'harsh_passed', 'harsh_forced', 'failed', 'blackmail', 'leash_snapped', 'leash_public', 'strikes', 'max_tension', 'end_trust']),
    ]
    for name, keys in groups:
        print(f'{name}:', ', '.join(f'{k} {a(k):.2f}' for k in keys))
    print('위기 속도 (시작 수 / 끝난 수 / 끝난 것의 평균 구간 / 1구간 안에 끝난 비율=시작 대비):')
    for t in ('strike', 'protest', 'resource', 'crowd'):
        st, rs = agg['crisis_%s_n' % t], agg['crisis_%s_resolved' % t]
        dur = agg['crisis_%s_dur' % t] / rs if rs else 0
        fast = agg['crisis_%s_fast' % t] / st if st else 0
        out['cr_' + t] = (st / n, dur, fast)
        print(f'  {t}: 판당 {st / n:.2f}, 끝남 {rs / st if st else 0:.0%}, 평균 {dur:.1f}구간, 1구간 안 {fast:.0%}')
    out['vote'] = agg['forced_passed'] / agg['forced'] if agg['forced'] else 0
    print(f"  위기 안건: 판당 {agg['forced'] / n:.2f}, 통과 {out['vote']:.0%}")
    ml_runs = agg['ml_declared']
    print(f"계엄: {ml_runs / n:.0%}판, 계엄 판의 평균 길이 {agg['ml_len'] / ml_runs if ml_runs else 0:.1f}구간")
    print(f"수단 점수 평균 {out['means']:.1f}, 8 이상 {out['dark8']:.0%}. 톤:",
          ', '.join(f'{k} {v / n:.0%}' for k, v in sorted(tone.items())))
    out['ml_rate'] = ml_runs / n
    for k in ('brink_any', 'war_any', 'ml_door_extend', 'ml_door_council', 'ml_door_brink', 'ml_door_war',
              'ml_door_captain', 'deaths', 'war_deaths', 'end_trust'):
        out[k] = agg[k] / n
    out['ml_len'] = agg['ml_len'] / ml_runs if ml_runs else 0
    return out


def check(res):
    c = res['caretaker']
    print('\n## 브리프 목표 확인')
    ck = c['revolt'] + c['coup']
    for d in ('tyrant', 'schemer_plus'):
        if d not in res:
            continue
        r = res[d]; rc = r['revolt'] + r['coup']
        ok1 = r['complete'] <= c['complete'] + 0.10
        ok3 = r['complete'] <= c['complete'] + 0.03
        ok2 = rc >= 1.5 * ck
        print(f"1.1 {d}: 완주 {r['complete']:.0%} vs caretaker {c['complete']:.0%}: +10%p 안 {'통과' if ok1 else '실패'}, "
              f"+3%p 안(코디네이터) {'통과' if ok3 else '실패'}; "
              f"반란+쿠데타 {rc:.0%} ≥ 1.5×{ck:.0%}={1.5 * ck:.0%} → {'통과' if ok2 else '실패'}")
    print(f"16.1 caretaker 완주 {c['complete']:.0%} ≥ 46%(S1a 56% −10%p) → {'통과' if c['complete'] >= 0.46 else '실패'}; "
          f"내전 직전 {c['brink_any']:.0%}(15~30%), 내전 {c['war_any']:.0%}(5~10%)")
    if 'saint' in res:
        print(f"15.3 saint 완주 {res['saint']['complete']:.0%} ≥ 35% → {'통과' if res['saint']['complete'] >= 0.35 else '실패'}")
    for p, r in res.items():
        ok = 5 <= r['signs'] <= 10 and 1 <= r['violence'] <= 3 and r['violent_deaths'] <= 2
        print(f"1.2 {p}: 징후 {r['signs']:.1f}(5~10), 실제 폭력 {r['violence']:.2f}(1~3), 폭력 사망 {r['violent_deaths']:.2f}(≤2)"
              f" → {'통과' if ok else '실패'}")


def baseline(n, places):
    """S1b를 끈 DarkRun이 s1a_balance.Run과 판마다 같은지 확인한다."""
    print('\n## S1a 기준선 (S1b 끔)')
    for policy in S1A_POLICIES:
        same = 0; ends = Counter()
        for i in range(n):
            a = A.Run(1000 + i, policy, places).play()
            b = DarkRun(1000 + i, policy, places, s1b=False).play()
            same += (a.end == b.end and a.stats == b.stats and a.seg == b.seg and a.trust == b.trust)
            ends[b.end] += 1
        print(f"{policy}: 끝 {', '.join(f'{k} {v / n:.0%}' for k, v in ends.most_common())}; s1a와 같은 판 {same}/{n}")


def main():
    n = 1000
    args = sys.argv[1:]
    if args and args[0].isdigit():
        n = int(args.pop(0))
    policies = list(DARK)
    do_base = False
    while args:
        a = args.pop(0)
        if a == '--baseline':
            do_base = True
        elif a == '--policies':
            policies = args.pop(0).split(',')
        elif a == '--tune':
            while args and '=' in args[0]:
                k, v = args.pop(0).split('=')
                tgt = Q if k in Q else P
                tgt[k] = float(v) if isinstance(tgt[k], float) else int(float(v))
    places = A.load_places()
    if do_base:
        baseline(n, places)
    if Q['ep_normal']:
        LAWS['emergency_powers']['kind'] = 'normal'  # S1b 판에만(기준선 뒤에 바꾼다)
    res = {}
    for p in policies:
        res[p] = report(p, n, places)
    if 'caretaker' in res:
        check(res)
    print('\n위기 속도 요약 (판당 시작 / 끝난 것 평균 구간 / 1구간 안 비율): strike | protest | resource | crowd | 위기 안건 통과')
    for p, r in res.items():
        print(f"{p:13s} " + ' | '.join(f"{r['cr_' + t][0]:.2f} {r['cr_' + t][1]:.1f} {r['cr_' + t][2]:.0%}"
                                      for t in ('strike', 'protest', 'resource', 'crowd')) + f" | {r['vote']:.0%}")
    print('\n내전 요약: policy brink% war% | 계엄 문: 연장 의회 직전 내전 경비대장 | deaths war_deaths end_trust')
    for p, r in res.items():
        print(f"{p:13s} {r['brink_any']:.0%} {r['war_any']:.0%} | {r['ml_door_extend']:.0%} {r['ml_door_council']:.0%} "
              f"{r['ml_door_brink']:.0%} {r['ml_door_war']:.0%} {r['ml_door_captain']:.0%} | "
              f"{r['deaths']:.2f} {r['war_deaths']:.2f} {r['end_trust']:.0f}")
    print('\n요약표: policy complete stranded ousted revolt coup | signs violence vdeaths | means dark8 | ml_rate ml_len')
    for p, r in res.items():
        print(f"{p:13s} {r['complete']:.0%} {r['stranded']:.0%} {r['ousted']:.0%} {r['revolt']:.0%} {r['coup']:.0%} | "
              f"{r['signs']:.1f} {r['violence']:.2f} {r['violent_deaths']:.2f} | {r['means']:.1f} {r['dark8']:.0%} | "
              f"{r['ml_rate']:.0%} {r['ml_len']:.1f}")


if __name__ == '__main__':
    main()
