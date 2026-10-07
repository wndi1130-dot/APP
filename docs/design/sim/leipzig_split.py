"""라이프치히 이탈 확인 (설계 도구, 게임 코드가 아니다).

s1a_balance.py의 24구간 판을 그대로 돌리고, 도착(24구간 정산 뒤)에 first_leg_story.md 7.7의 이탈 장면을 붙인다.

  - 23구간 시작: 떠나려는 몫(share)이 있는 칸마다 징후 쪽지 하나.
  - 23·24구간 정산: share가 있는 칸이 식량·의약품을 조금씩 빼 둔다(stash).
  - 도착: 칸마다 share, 떠나려는 사람 n, 대표도 가나를 정하고 정책별로 허브에서 고른다.
      돌봄(caretaker, nodeal, idealist, caretaker_random): 설득이 되면 설득, 아니면 보낸다.
      협박(schemer): 무력이 되면 무력, 아니면 보낸다.
      방치(passive): 보낸다.

넣지 않은 것: '우리 몫을 내놔라' 표결(늘 안 다룬 것으로 친다. 그래서 보내면 늘 더 가져간다),
AI 지도자의 공간 요구·무력 권유, 징후 뒤 두 구간의 정책 반응(정책은 징후를 모른다), 대표 승계, 탄압 뒤탈.
결속도는 s1a에 계기가 없어 COH0(시작값)을 쓴다. 상징물은 s1a가 stats['got_symbol']로만 센다.
사용: python3 -I docs/design/sim/leipzig_split.py [판 수]
"""
import math
import random
import sys
from collections import Counter, defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import s1a_balance as S  # noqa: E402

P, COMMS = S.P, S.COMMS
NAME = dict(tail='꼬리칸', engine='기관실', guard='경비대', medtech='의무진', front='앞칸')
CARE = ('caretaker', 'nodeal', 'idealist')
HARSH = ('schemer',)
# 7.7 제안 수치
L = dict(omen_seg=23, leak_rate=0.1, coh_lock=0.75, jitter=0.10, share_cap=0.80, grudge_add=0.20,
         persuade_trust=60, persuade_trust_hi=75, persuade_grudge=1, persuade_cost=5,
         force_guard_rel=15, force_escape=0.25, hurt=(0.05, 0.10), dead=(0.01, 0.03),
         hostile_coal=5, tail_food=0.15)


def rnd(x):  # 반올림(0.5는 올린다). 파이썬 round는 짝수로 가서 쓰지 않는다
    return int(math.floor(x + 0.5))


class Leipzig(S.Run):
    def __init__(self, seed, policy, places):
        super().__init__(seed, policy, places)
        self.seed = seed
        self.stash = {c: Counter() for c in COMMS}  # 칸마다 미리 빼 둔 식량·의약품
        self.omens = 0
        self.hub = None

    def roll(self, c, tag):  # 판·칸마다 고정 해시 굴림
        return random.Random(f'{self.seed}:{c}:{tag}').random()

    def share(self, c):
        rel = self.rel[c]
        s = 0.0 if rel >= -14 else 0.10 if rel >= -39 else 0.30 if rel >= -69 else 0.60
        if self.grudge[c] >= 2:
            s += L['grudge_add']
        s = min(s, L['share_cap'])
        if S.COH0[c] < L['coh_lock'] and s > 0:
            s = S.clamp(s + (self.roll(c, 'jitter') * 2 - 1) * L['jitter'], 0, L['share_cap'])
        return s

    def step(self):
        if self.seg + 1 == L['omen_seg']:  # 23구간 시작: 징후
            self.omens = sum(1 for c in COMMS if self.share(c) > 0)
        super().step()
        if self.seg >= L['omen_seg'] and self.end is None:
            self.leak()

    def leak(self):
        total = sum(self.pop.values())
        food, med = self.food, self.med  # 정산 직후 재고 기준, 칸마다 같은 재고에서 셈
        for c in COMMS:
            s = self.share(c)
            if s <= 0:
                continue
            k = s * self.pop[c] / total * L['leak_rate']
            for key, have in (('food', food), ('med', med)):
                amt = max(0.0, have) * k
                setattr(self, key, getattr(self, key) - amt)
                self.stash[c][key] += amt

    # ---- 허브 ----
    def arrive(self):
        self.arrive_rel, self.arrive_grudge = dict(self.rel), dict(self.grudge)
        total = sum(self.pop.values())
        # 1인당 몫은 도착 순간의 재고(+빼 둔 것)로 한 번 정한다. 칸 처리 순서에 안 흔들리게
        store = dict(food=self.food + sum(st['food'] for st in self.stash.values()),
                     coal=self.coal, med=self.med + sum(st['med'] for st in self.stash.values()))
        percap = {k: max(0.0, v) / total for k, v in store.items()}
        out = dict(comm={}, lost=Counter(), hurt=0, dead=0, guard_hurt=0, promises=0,
                   persuade_ok=0, force_ok=0, persuade=0, force=0, send=0)
        for c in COMMS:
            s = self.share(c)
            n = min(max(1, rnd(s * self.pop[c])), self.pop[c] - 1) if s > 0 else 0
            if n <= 0:
                out['comm'][c] = dict(choice='stayed', n=0, left=0, leader=False)
                continue
            leader = s >= 0.30 if S.COH0[c] >= L['coh_lock'] else self.roll(c, 'leader') < s
            can_p = self.trust >= L['persuade_trust'] and self.grudge[c] <= L['persuade_grudge']
            can_f = (self.rel['guard'] >= L['force_guard_rel'] and c != 'guard'
                     and self.pop['guard'] >= n / 4)
            out['persuade_ok'] += can_p; out['force_ok'] += can_f
            if self.policy in CARE and can_p:
                choice = 'persuaded'
            elif self.policy in HARSH and can_f:
                choice = 'forced'
            else:
                choice = 'left'
            stash = self.stash[c]
            if choice != 'left':  # 남으면 빼 둔 것이 돌아온다
                self.food += stash['food']; self.med += stash['med']
            if choice == 'persuaded':
                left = rnd(n / 2) if self.trust < L['persuade_trust_hi'] else rnd(n / 4)
                self.trust -= L['persuade_cost']; out['promises'] += 1
                self.carry(left, percap, 1.0, out['lost'])
                leader = False  # 설득된 판에서 대표는 남는다고 친다(명세에 없다)
                out['persuade'] += 1
            elif choice == 'forced':
                left = rnd(n * L['force_escape'])
                self.carry(left, percap, 0.5, out['lost'])
                hurt = max(1, rnd(n * self.r.uniform(*L['hurt'])))
                dead = rnd(n * self.r.uniform(*L['dead']))
                g_hurt = self.r.randint(1, 2)
                self.pop[c] -= dead; self.injured += hurt + g_hurt
                out['hurt'] += hurt; out['dead'] += dead; out['guard_hurt'] += g_hurt
                self.rel[c] = S.clamp(self.rel[c] - 20, -100, 100)
                self.offend(c); self.fervor[c] = min(3, self.fervor[c] + 1); self.tension += 15
                for o in COMMS:
                    if o not in (c, 'guard'):
                        self.rel[o] = S.clamp(self.rel[o] - 5, -100, 100)
                self.rel['guard'] = S.clamp(self.rel['guard'] + 5, -100, 100)
                leader = False
                out['force'] += 1
            else:  # 보낸다: 빼 둔 몫은 들고 갈 몫에서 이미 가져간 셈
                left = n
                for k in ('food', 'med'):
                    carry = percap[k] * n
                    self.take(k, max(0.0, carry - stash[k]))
                    out['lost'][k] += max(carry, stash[k])
                self.take('coal', percap['coal'] * n); out['lost']['coal'] += percap['coal'] * n
                self.extra(c, out['lost'])  # 표결을 안 다뤘으니 늘 더 가져간다
                out['send'] += 1
            self.pop[c] -= left
            out['comm'][c] = dict(choice=choice, n=n, left=left, leader=leader and left > 0)
        self.hub = out

    def take(self, key, amt):
        amt = max(0.0, min(amt, getattr(self, key)))  # 재고가 0 아래(굶주림)면 가져갈 것이 없다
        setattr(self, key, getattr(self, key) - amt)
        return amt

    def carry(self, left, percap, frac, lost):
        for k in ('food', 'coal', 'med'):
            lost[k] += self.take(k, percap[k] * left * frac)

    def extra(self, c, lost):
        """적대로 떠나거나 표결 없이 보내면 그 칸이 맡던 것을 더 가져간다."""
        if c == 'guard':
            sym = math.ceil(self.stats['got_symbol'] / 2)
            self.stats['got_symbol'] -= sym; lost['symbol'] += sym
        elif c == 'engine':
            lost['coal'] += self.take('coal', L['hostile_coal'])
        elif c == 'medtech':
            lost['med'] += self.take('med', self.med / 2)
        elif c == 'front':
            lost['lux'] += self.take('lux', self.lux / 2)
        elif c == 'tail':
            lost['food'] += self.take('food', self.food * L['tail_food'])

    def play(self):
        super().play()
        if self.end == 'complete':
            self.arrive()
        return self


def summarize(policy, n, places):
    reached = 0; any_left = 0; omen = 0
    agg = Counter(); left_c = Counter(); choice_c = defaultdict(Counter); want_c = Counter(); leader_c = Counter()
    rel_c = Counter(); hostile_c = Counter()
    for i in range(n):
        run = Leipzig(1000 + i, policy, places).play()
        if run.hub is None:
            continue
        reached += 1; h = run.hub; omen += run.omens
        for c in COMMS:
            rel_c[c] += run.arrive_rel[c]; hostile_c[c] += run.arrive_grudge[c] >= 2
        total_left = sum(v['left'] for v in h['comm'].values())
        any_left += total_left > 0
        agg['left'] += total_left
        for k in ('hurt', 'dead', 'guard_hurt', 'promises', 'persuade_ok', 'force_ok', 'persuade', 'force', 'send'):
            agg[k] += h[k]
        for k, v in h['lost'].items():
            agg['lost_' + k] += v
        for c, v in h['comm'].items():
            left_c[c] += v['left']; want_c[c] += v['n']; leader_c[c] += v['leader']
            choice_c[c][v['choice']] += 1
    r = max(1, reached)
    print(f'\n## {policy} ({n}판)')
    print(f'라이프치히 도착 {reached / n:.0%} | 누군가 떠난 판 {any_left / r:.0%} | 23구간 징후 쪽지 평균 {omen / r:.2f}')
    print(f"떠난 사람 평균 {agg['left'] / r:.1f}: " +
          ', '.join(f'{NAME[c]} {left_c[c] / r:.1f}(원함 {want_c[c] / r:.1f})' for c in COMMS))
    asked = agg['send'] + agg['persuade'] + agg['force']
    print(f"고르기(판당): 보냄 {agg['send'] / r:.2f}, 설득 {agg['persuade'] / r:.2f}(가능 {agg['persuade_ok'] / r:.2f}), "
          f"무력 {agg['force'] / r:.2f}(가능 {agg['force_ok'] / r:.2f}) / 떠나려는 칸 {asked / r:.2f}")
    print(f"무력 사상(판당): 다침 {agg['hurt'] / r:.2f}, 죽음 {agg['dead'] / r:.2f}, 경비대 다침 {agg['guard_hurt'] / r:.2f}"
          f" | 약속 {agg['promises'] / r:.2f}")
    print(f"잃은 물자(판당, 유출+들고 감): 식량 {agg['lost_food'] / r:.1f}, 석탄 {agg['lost_coal'] / r:.1f}, "
          f"의약품 {agg['lost_med'] / r:.1f}, 사치품 {agg['lost_lux'] / r:.1f}, 상징물 {agg['lost_symbol'] / r:.2f}")
    print('도착 관계 평균(적의 2+): ' + ', '.join(f'{NAME[c]} {rel_c[c] / r:+.0f}({hostile_c[c] / r:.0%})' for c in COMMS))
    print('칸별 결과(도착 판 중):')
    for c in COMMS:
        cc = choice_c[c]
        print(f'  {NAME[c]}: ' + ', '.join(f'{k} {cc[k] / r:.0%}' for k in ('stayed', 'left', 'persuaded', 'forced'))
              + f', 대표 감 {leader_c[c] / r:.0%}')
    top = max(COMMS, key=lambda c: left_c[c])
    print(f'가장 많이 떠나는 칸: {NAME[top]}')


def main():
    n = 1000
    if len(sys.argv) > 1 and sys.argv[1].isdigit():
        n = int(sys.argv[1])
    places = S.load_places()
    for policy in ('passive', 'idealist', 'nodeal', 'caretaker', 'schemer', 'caretaker_random'):
        summarize(policy, n, places)


if __name__ == '__main__':
    main()
