"""S1c 기술이 S1a의 석탄·식량 압박을 얼마나 흐리는지 재는 확인용 스크립트 (설계 도구, 게임 코드가 아니다).

s1a_balance.py의 판을 그대로 돌리고, s1c_domestic.md 7.3의 기술 다섯을 정해진 구간에 켠다.
  E1 누설 막기      달리기 석탄 -0.5
  E2 압력 조절      달리기 석탄 -1
  X1 짐 꾸리기      정차 산출 ×1.1
  M3 가 식량 보존   식량 소모 ×0.9 (훈제: 목재만 들어 석탄엔 안 닿는다)
  E5 단열 개조      꼬리칸 세 칸 중 두 칸 온기 +10 → 꼬리칸 온기 +6.7
그리고 S1c가 새로 쓰는 석탄 하나를 넣는다: 더운물 '드물게'(16.2) = 1 × 인구/40 × 0.1 ≈ 0.5/구간.

넣지 않은 것: 부품·자재(석탄·식량에 안 닿는다), 고장, 지식 카운트다운, 간부 맡기기, 위생 카드, 냉기 누적.
기술이 켜지는 구간은 손으로 정한 세 경우(이름, 늦음, 없음)다. 실제 S1c 판의 복원 속도는 조각 운에 달려 있다.

두 번째 모드(--law)는 2026-10-07 사용자 결정 뒤의 7.3이다: 기술이 자원을 아끼지 않고 법을 바꾼다.
  E1 → 법 6 눈 녹이기 당번의 온기 벌 없음, 노출 벌 절반
  E2 → 법 5 난방 배당의 온기 벌 절반, 경비대 벌 없음
  E3 가 → 법 4 공동 난방의 석탄 +1.25 → +0.6
  E5 → 단열한 꼬리칸 두 칸은 법 5의 벌 없음 (꼬리칸 벌 ×1/3)
  X1 → 법 7 아동 노동의 '짐 꾸리기만' 변형
  더운물 '드물게'는 양쪽 다 0.5/구간.

사용: python3 docs/design/sim/s1c_tech_check.py [판 수]
      python3 docs/design/sim/s1c_tech_check.py --law [판 수]
"""
import sys
from collections import Counter

import s1a_balance as s1a

# 기술이 켜지는 구간 (그 구간의 시작부터 효과)
SCHEDULES = {
    'none': {},
    'early': dict(E1=4, X1=6, E2=8, M3=10, E5=12),
    'typical': dict(E1=6, X1=9, E2=12, M3=15, E5=18),
    'late': dict(E1=10, X1=13, E2=16, M3=19, E5=22),
}
HOT_WATER = 0.5  # 더운물 '드물게'의 석탄/구간 (S1c에서만)


class S1cRun(s1a.Run):
    def __init__(self, seed, policy, places, sched, hot_water):
        super().__init__(seed, policy, places)
        self.sched = sched
        self.hot_water = hot_water
        self.saved = Counter()

    def on(self, tech):
        return tech in self.sched and self.seg >= self.sched[tech]

    def res(self, key, default=0.0):
        out = super().res(key, default)
        if key == 'food_mult' and self.on('M3'):
            out *= 0.9
        if key == 'haul_mult' and self.on('X1'):
            out *= 1.1
        return out

    def step(self):
        nxt = self.seg + 1
        run0 = s1a.P['coal_run']
        cut = (0.5 if 'E1' in self.sched and nxt >= self.sched['E1'] else 0) + \
              (1.0 if 'E2' in self.sched and nxt >= self.sched['E2'] else 0)
        if 'E5' in self.sched and nxt == self.sched['E5']:
            self.base['tail'][0] += 6.7
        s1a.P['coal_run'] = run0 - cut
        try:
            self.coal -= self.hot_water
            super().step()
        finally:
            s1a.P['coal_run'] = run0
        self.saved['coal_run'] += cut
        self.saved['hot_water'] += self.hot_water


def measure(policy, n, places, sched_name, hot_water):
    ends = Counter(); agg = Counter()
    for i in range(n):
        run = S1cRun(1000 + i, policy, places, SCHEDULES[sched_name], hot_water).play()
        ends[run.end] += 1
        for k in ('forced', 'harsh_passed', 'low_coal_segments', 'emergency_used', 'starving_segments', 'deaths'):
            agg[k] += run.stats[k]
        agg['end_coal'] += run.coal
        agg['end_food'] += run.food
        agg['coal_run_saved'] += run.saved['coal_run']
        agg['hot_water'] += run.saved['hot_water']
        agg['common_heating'] += 'common_heating' in run.passed
        agg['heat_quota'] += 'heat_quota' in run.passed
        agg['snow_duty'] += 'snow_duty' in run.passed
    return ends, agg


def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 500
    places = s1a.load_places()
    print('정책 | 기술 | 더운물 | 완주 | 좌초 | 위기 안건/판 | 가혹 법/판 | 끝 석탄 | 끝 식량 | 달리기 석탄 절약 | 공동 난방 | 난방 배당 | 눈 녹이기')
    for policy in ('caretaker', 'nodeal'):
        for sched in ('none', 'early', 'typical', 'late'):
            for hw in ((0.0,) if sched == 'none' else (0.0, HOT_WATER)):
                ends, a = measure(policy, n, places, sched, hw)
                print(f"{policy} | {sched} | {hw} | {ends['complete'] / n:.0%} | {ends['stranded'] / n:.0%} | "
                      f"{a['forced'] / n:.2f} | {a['harsh_passed'] / n:.2f} | {a['end_coal'] / n:.0f} | {a['end_food'] / n:.0f} | "
                      f"{a['coal_run_saved'] / n:.1f} | {a['common_heating'] / n:.0%} | {a['heat_quota'] / n:.0%} | {a['snow_duty'] / n:.0%}")


# ---- 2026-10-07 사용자 결정 뒤: 기술이 자원을 아끼지 않고 법을 바꾼다 (s1c_domestic.md 7.3) ----
# 기술이 켜지면 그 법의 효과를 바꾼다. 이미 통과한 법이면 차이만큼 처지를 되돌린다.
import copy

LAW_SCHEDULES = {
    'law_none': {},
    'law_typical': dict(E1=6, X1=9, E2=12, E3=15, E5=18),
    'law_early': dict(E1=4, X1=6, E2=8, E3=10, E5=12),
}


def law_mods(on):
    """켜진 기술 집합 → 바뀐 법 효과."""
    out = {}
    if 'E1' in on:  # 눈 녹이기 당번: 온기 벌 없음, 노출 벌 절반
        out['snow_duty'] = dict(mats=dict(tail=(0, 0, 0, 2), front=(0, 0, 0, 8), medtech=(0, 0, 0, 2)))
    tail_q = -10 * (0.5 if 'E2' in on else 1) * (1 / 3 if 'E5' in on else 1)
    if 'E2' in on or 'E5' in on:  # 난방 배당: 온기 벌 절반(E2), 단열한 꼬리칸 두 칸은 벌 없음(E5)
        med_q = -5 if 'E2' in on else -10
        guard_q = 0 if 'E2' in on else -5
        out['heat_quota'] = dict(mats=dict(tail=(tail_q, 0, 0, 0), medtech=(med_q, 0, 0, 0), guard=(guard_q, 0, 0, 0)))
    if 'X1' in on:  # 아동 노동 → 짐 꾸리기만: 산출 +10%, 노출 없음, 공포 +2, 의무진 −5
        out['child_labor'] = dict(mats={}, rels=dict(tail=-5, medtech=-5), res=dict(haul_mult=1.1, fear_once=2))
    return out


class LawTechRun(s1a.Run):
    def __init__(self, seed, policy, places, sched, hot_water):
        super().__init__(seed, policy, places)
        self.sched = sched
        self.hot_water = hot_water
        self.orig = {k: copy.deepcopy(s1a.LAWS[k]) for k in ('snow_duty', 'heat_quota', 'child_labor', 'common_heating')}
        self.on = set()

    def set_laws(self):
        mods = law_mods(self.on)
        for k, base in self.orig.items():
            L = copy.deepcopy(base)
            for field, val in mods.get(k, {}).items():
                L[field] = val
            old = s1a.LAWS[k]
            if k in self.passed:  # 이미 통과한 법이면 처지 차이를 반영한다
                for c in set(old['mats']) | set(L['mats']):
                    o = old['mats'].get(c, (0, 0, 0, 0)); n = L['mats'].get(c, (0, 0, 0, 0))
                    for i in range(4):
                        self.base[c][i] += n[i] - o[i]
            s1a.LAWS[k] = L

    def step(self):
        nxt = self.seg + 1
        new = {t for t, s in self.sched.items() if nxt >= s} - self.on
        if new:
            self.on |= new
            self.set_laws()
        self.coal -= self.hot_water
        if 'E3' in self.on and 'common_heating' in self.passed:
            self.coal += 0.6  # 배관 공동 난방: 공동 난방 법의 석탄 약 +1.25 → +0.6
        super().step()

    def play(self):
        try:
            return super().play()
        finally:
            for k, v in self.orig.items():
                s1a.LAWS[k] = v


def measure_law(policy, n, places, sched_name, hot_water):
    ends = Counter(); agg = Counter()
    for i in range(n):
        run = LawTechRun(1000 + i, policy, places, LAW_SCHEDULES[sched_name], hot_water).play()
        ends[run.end] += 1
        for k in ('forced', 'harsh_passed', 'bought_laws'):
            agg[k] += run.stats[k]
        agg['end_coal'] += run.coal
        agg['end_food'] += run.food
        agg['end_tail'] += run.rel['tail']
        for law in ('common_heating', 'heat_quota', 'snow_duty', 'child_labor'):
            agg[law] += law in run.passed
    return ends, agg


def main_law(n=500):
    places = s1a.load_places()
    print('정책 | 기술 | 더운물 | 완주 | 좌초 | 반란 | 위기 안건/판 | 가혹 법/판 | 산 법/판 | 끝 석탄 | 끝 식량 | 꼬리칸 끝 관계 | 공동 난방 | 난방 배당 | 눈 녹이기 | 아동 노동')
    for policy in ('caretaker', 'nodeal'):
        for sched, hw in (('law_none', 0.0), ('law_typical', 0.0), ('law_none', HOT_WATER), ('law_typical', HOT_WATER), ('law_early', HOT_WATER)):
            ends, a = measure_law(policy, n, places, sched, hw)
            print(f"{policy} | {sched} | {hw} | {ends['complete'] / n:.0%} | {ends['stranded'] / n:.0%} | {ends['revolt'] / n:.0%} | "
                  f"{a['forced'] / n:.2f} | {a['harsh_passed'] / n:.2f} | {a['bought_laws'] / n:.2f} | {a['end_coal'] / n:.0f} | {a['end_food'] / n:.0f} | "
                  f"{a['end_tail'] / n:+.0f} | {a['common_heating'] / n:.0%} | {a['heat_quota'] / n:.0%} | {a['snow_duty'] / n:.0%} | {a['child_labor'] / n:.0%}")


if __name__ == '__main__':
    if '--law' in sys.argv:
        sys.argv.remove('--law')
        main_law(int(sys.argv[1]) if len(sys.argv) > 1 else 500)
    else:
        main()
