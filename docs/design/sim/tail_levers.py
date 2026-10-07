"""꼬리칸 노출·과밀을 낮추는 수단을 첫 구간 판에 붙여 본다 (설계 도구, 게임 코드가 아니다).

사용자 결정(2026-10-07 16:00, '수단 더하기'): 지지 하나가 정답이 되지 않게 손잡이를 여럿 둔다.
first_leg_story.md 6.4의 규칙을 leipzig_first_leg.py 판(첫 구간 6구간 + 라이프치히 이탈)에 얹는다.

  - 작업조(운송조): 정차마다 열차장이 운송조를 낼 칸을 고른다. 낸 칸은 노출 +5, 안 낸 칸은 노출 −10(쉼 바닥까지).
    꼬리칸이 아닌 칸은 손에 익지 않아 운반이 준다(의무진 ×0.9, 앞칸 ×0.8, 경비대 ×0.9). 의무진·앞칸은 궂은일 반감 관계 −3.
    그 정차의 다침은 낸 칸 관계를 1명마다 −2 깎고, 죽음도 그 칸에서 난다. 기관실은 화부라 못 낸다. 경비대 호위는 늘 하던 일이라 따로 안 센다.
  - 급수탑 눈 녹이기: 녹일 칸을 고른다. 그 칸 노출 +10(작업조와 같은 반감).
  - 공간 레버(0~2단): 한 단에 꼬리칸 과밀 −10, 내주는 칸 과밀 +10. 당길 때 내주는 칸 관계 −3, 당겨 둔 동안 구간마다 단당 −1.
  - 지지(비교용, s1a 3.6): 사치품 2로 꼬리칸 관계 +10, 열기 −1, 앞칸 −3. 구간마다 한 번.

사용: python3 -I docs/design/sim/tail_levers.py [판 수]
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import first_leg_budget as F  # noqa: E402
import leipzig_first_leg as LF  # noqa: E402
import leipzig_split as LS  # noqa: E402
import s1a_balance as S  # noqa: E402

P = S.P
T = dict(crew_gain=5, rest=10, rest_floor=dict(tail=35, medtech=25, front=10),
         haul=dict(tail=1.0, guard=0.9, medtech=0.9, front=0.8), chore_rel=-3, hurt_rel=-2,
         snow_exposure=10, space_step=10, space_max=2, space_pull_rel=-3, space_hold_rel=-1,
         support_lux=2, support_rel=10, support_repeat=10, support_gap=3, support_other=-3)
CFG = dict(crew=True, space=True, support=False)  # 판 묶음마다 바꾼다. crew=False는 늘 꼬리칸(규칙만 켬)
CHORE = ('medtech', 'front')  # 늘 하던 일이 아닌 칸


class TailLevers(LF.FirstLegSplit):
    def __init__(self, seed, policy, places):
        super().__init__(seed, policy, places)
        self.space = 0
        self.giver = None
        self.crew = None
        self.last_support = -99

    # ---- 작업조 ----
    def pick_crew(self):
        if self.policy == 'passive' or not CFG['crew']:
            return 'tail'
        m = self.m
        if m['tail'][3] + T['crew_gain'] <= 50:
            return 'tail'
        ok = [c for c in ('medtech', 'front', 'guard') if m[c][3] + T['crew_gain'] <= 50 and self.rel[c] >= 5
              and not (c == 'guard' and self.rel['guard'] < 25)]  # 경비대는 무력 조건(호의)을 지킬 여유가 있을 때만
        return max(ok, key=lambda c: (self.rel[c], -m[c][3])) if ok else 'tail'

    def labor(self, c, gain):
        self.base[c][3] += gain
        if c in CHORE:
            self.rel[c] += T['chore_rel']
        self.stats['crew_' + c] += 1

    def rest(self, busy):
        for c, floor in T['rest_floor'].items():
            if c not in busy:
                self.base[c][3] = max(min(floor, self.base[c][3]), self.base[c][3] - T['rest'])

    def stop(self):
        name, _, pid = F.LEGS[self.seg - 1]
        if pid is None:
            self.rest(()); return
        self.crew = self.pick_crew()
        haul0 = P['haul_total']
        # s1a_balance.stop은 작업 거부(×0.7)를 늘 꼬리칸으로 본다. 거부는 실제로 나간 칸의 것으로 바꿔 낀다
        refuse = lambda c: self.fervor[c] >= 1 and self.rel[c] <= -40
        fix = (0.7 if refuse(self.crew) else 1) / (0.7 if refuse('tail') else 1)
        P['haul_total'] = haul0 * T['haul'][self.crew] * fix
        passed, inj0, resc0 = self.stats['passed_stops'], self.injured, self.stats['rescued']
        try:
            super().stop()
        finally:
            P['haul_total'] = haul0
        if self.stats['passed_stops'] > passed:
            self.rest(()); self.crew = None; return
        hurt = max(0, (self.injured - inj0) - (self.stats['rescued'] - resc0))
        self.rel[self.crew] += T['hurt_rel'] * hurt
        self.labor(self.crew, T['crew_gain'])
        self.rest((self.crew,))
        self.crew = None

    def on_death(self, n, c='tail'):
        if self.crew and c == 'tail':
            c = self.crew  # 정차의 죽음은 나간 칸에서 난다
        super().on_death(n, c)

    def water_tower(self):
        if self.policy == 'passive':
            self.water_skip = True; self.stats['water_skip'] += 1
        elif self.coal > 20:
            self.coal -= P['water_fire_coal']; self.stats['water_fire'] += 1
        else:
            c = self.pick_crew() if CFG['crew'] else 'tail'
            self.base[c][3] += T['snow_exposure']
            if c in CHORE:
                self.rel[c] += T['chore_rel']
            self.stats['water_snow'] += 1; self.stats['snow_' + c] += 1

    # ---- 공간 레버와 지지 ----
    def policy_levers(self):
        super().policy_levers()
        if self.policy == 'passive':
            return
        if CFG['space']:
            self.space_lever()
        if CFG['support'] and self.lux >= T['support_lux'] and self.rel['tail'] <= 0:
            self.lux -= T['support_lux']
            # 같은 칸을 support_gap 구간 안에 또 지지하면 support_repeat만 오른다(제안 비교용, 기본은 줄지 않음)
            again = self.seg - self.last_support < T['support_gap']
            self.rel['tail'] = S.clamp(self.rel['tail'] + T['support_repeat' if again else 'support_rel'], -100, 100)
            self.last_support = self.seg
            self.fervor['tail'] = max(0, self.fervor['tail'] - 1)
            self.rel['front'] += T['support_other']
            self.stats['support'] += 1

    def space_lever(self):
        m = self.m
        if self.space and (self.rel[self.giver] < -15 or m['tail'][2] < 50):
            self.move(-1)  # 내준 칸이 돌아서거나 꼬리칸이 넉넉해지면 한 단 푼다. 남은 단의 유지비는 아래에서 그대로 문다
        elif self.space < T['space_max'] and m['tail'][2] >= 65:
            if self.giver is None:
                ok = [c for c in ('front', 'medtech', 'guard') if self.rel[c] >= 0 and m[c][2] + 20 <= 60]
                if not ok:
                    return
                self.giver = min(ok, key=lambda c: m[c][2])
            if self.rel[self.giver] >= 0:
                self.move(1)
        if self.space:
            self.rel[self.giver] += T['space_hold_rel'] * self.space

    def move(self, d):
        self.space += d
        self.base['tail'][2] -= d * T['space_step']
        self.base[self.giver][2] += d * T['space_step']
        if d > 0:
            self.rel[self.giver] += T['space_pull_rel']; self.stats['space_pull'] += 1
        if self.space == 0:
            self.giver = None

    def arrive(self):
        self.stats['arrive_tail_ex'] += self.m['tail'][3]; self.stats['arrive_tail_cr'] += self.m['tail'][2]
        self.stats['arrive_coal'] += self.coal; self.stats['arrive_food'] += self.food
        super().arrive()


def run_set(label, policies, n, places, **cfg):
    CFG.update(crew=True, space=True, support=False); CFG.update(cfg)
    print(f'\n# {label} {cfg}')
    for policy in policies:
        LS.summarize(policy, n, places)
        agg = {}
        runs = [TailLevers(1000 + i, policy, places).play() for i in range(n)]
        for k in ('crew_tail', 'crew_medtech', 'crew_front', 'crew_guard', 'space_pull', 'support',
                  'arrive_tail_ex', 'arrive_tail_cr', 'arrive_coal', 'arrive_food', 'water_snow', 'snow_tail', 'snow_front', 'snow_medtech'):
            agg[k] = sum(r.stats[k] for r in runs) / n
        print('  수단:', ', '.join(f'{k} {v:.2f}' for k, v in agg.items()))


def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 1000
    for a in sys.argv[2:]:  # --tune key=value
        k, v = a.split('=')
        T[k] = type(T[k])(v)
    S.P.update(F.FIRST)
    LS.L['omen_seg'] = F.FIRST['segments'] - 1
    LS.Leipzig = TailLevers
    places = S.load_places()
    pols = ('passive', 'caretaker', 'schemer')
    run_set('규칙만(늘 꼬리칸, 레버 안 씀)', ('caretaker',), n, places, crew=False, space=False)
    run_set('지지만', ('caretaker',), n, places, crew=False, space=False, support=True)
    run_set('작업조 돌리기만', ('caretaker',), n, places, space=False)
    run_set('공간 레버만', ('caretaker',), n, places, crew=False)
    run_set('새 수단 둘(기본안)', pols, n, places)
    run_set('새 수단 둘 + 지지', ('caretaker',), n, places, support=True)
    if T['support_repeat'] != T['support_rel']:
        run_set('지지만(되풀이 줄임)', ('caretaker',), n, places, crew=False, space=False, support=True)


if __name__ == '__main__':
    main()
