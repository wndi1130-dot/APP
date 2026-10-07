"""첫 구간(볼슈틴 → 라이프치히) 자원 수지 확인 (설계 도구, 게임 코드가 아니다).

s1a_balance.py의 판 규칙을 그대로 쓰고, 첫 구간에 맞는 것만 바꾼다(first_leg_story.md 7.8).

  - 구간 6개 = 정차 사이의 실제 거리. 달리기 석탄은 100km에 6(s1a 1.7)을 거리로 나눈다.
  - 정차 다섯 곳의 장소 유형은 이야기 순서대로 고정한다(화물역, 주택가, 공장, 병원, 화물역). 라이프치히는 허브라 정차가 없다.
  - 회기는 정차마다 한 번(3장 기본값).
  - 술레후프 급수탑: 그냥 떠나면 다음 구간 달리기 석탄 ×1.5, 불로 녹이면 석탄 3, 눈을 녹이면 꼬리칸 노출 +10.
  - 발전소 갈탄: 석탄 재고에 절반 값으로 들어가고 따로 센다. 구간 석탄 소비는 갈탄부터 깎고,
    갈탄을 땐 구간엔 기관실 노출 +3. 갈탄이 0이 되면 멈춘다(N24).
  - 더운물(S1c 16장) 구간당 0.5는 --hot 으로 켠다.

사용: python3 docs/design/sim/first_leg_budget.py [판 수] [--tune key=value ...] [--hot]
"""
import sys
from collections import Counter, defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import s1a_balance as S  # noqa: E402

P = S.P
# (구간 끝의 곳, 거리 km, 장소 유형 id). 마지막 구간은 라이프치히 허브(정차 없음)
LEGS = [
    ('술레후프', 54, 'place_freight_draft'),
    ('구벤', 71, 'place_houses_draft'),
    ('발전소', 17, 'place_factory_draft'),
    ('코트부스', 21, 'place_hospital_draft'),
    ('팔켄베르크', 78, 'place_freight_draft'),
    ('라이프치히', 71, None),
]
FIRST = dict(segments=len(LEGS), session_every=1, coal0=45, food0=55, haul_total=20, lever_line=25,
             lignite_value=0.5, lignite_exposure=3, water_fire_coal=3, water_skip_mult=1.5, hot_water=0.0)


class FirstLeg(S.Run):
    def __init__(self, seed, policy, places):
        super().__init__(seed, policy, places)
        self.place_by_id = {p[0]: p for p in places}
        self.lignite = 0.0
        self.water_skip = False
        self.coal_used = Counter()

    def step(self):
        _, km, _ = LEGS[self.seg]  # self.seg은 super().step()에서 1 오른다
        run = 6 * km / 100
        if self.water_skip:
            run *= P['water_skip_mult']; self.water_skip = False
        P['coal_run'] = run
        before = self.coal
        super().step()
        used = max(0.0, before - self.coal)
        self.coal_used['run'] += run
        # 갈탄은 이번 구간 소비에서 먼저 깎인다
        if self.lignite > 0 and used > 0:
            burned = min(self.lignite, used)
            self.lignite -= burned
            self.base['engine'][3] += P['lignite_exposure']
            self.stats['lignite_segments'] += 1
        if P['hot_water']:
            self.coal -= P['hot_water']
        if self.seg == 2 and self.stats['deaths'] == 0:
            self.stats['no_death_by_guben'] += 1

    def stop(self):
        name, _, pid = LEGS[self.seg - 1]
        if pid is None:
            return  # 라이프치히 허브
        saved = self.places
        self.places = [self.place_by_id[pid]]
        coal_before, passed = self.coal, self.stats['passed_stops']
        super().stop()
        self.places = saved
        if self.stats['passed_stops'] > passed:
            return  # 지나쳤다
        gained = self.coal - coal_before + P['coal_stop']
        if name == '발전소' and gained > 0:
            # 저탄장의 석탄은 갈탄이다. 반값으로 들어가고 따로 센다
            self.coal -= gained * (1 - P['lignite_value'])
            self.lignite += gained * P['lignite_value']
        if gained > 0:
            self.stats['coal_from_' + name] += gained * (P['lignite_value'] if name == '발전소' else 1)
        if name == '술레후프':
            self.water_tower()

    def water_tower(self):
        if self.policy == 'passive':
            self.water_skip = True; self.stats['water_skip'] += 1
        elif self.coal > 20:
            self.coal -= P['water_fire_coal']; self.stats['water_fire'] += 1
        else:
            self.base['tail'][3] += 10; self.stats['water_snow'] += 1

    def policy_target(self, pid, loot):
        left = P['segments'] - self.seg + 1
        coal_need = left * 10.5 * 0.7
        food_need = left * 10
        need = {'coal': self.coal / coal_need, 'food': self.food / food_need}
        if self.med < 8:
            need['medicine'] = self.med / 20
        if self.policy == 'passive':
            return max(('coal', 'food'), key=lambda k: loot[k] * (1.5 - need[k]))
        for k in sorted(need, key=need.get):
            if need[k] < 1.2 and loot.get(k, 0) >= 25:
                return k
        if min(need['coal'], need['food']) > 1.2:
            return max(('medicine', 'luxury', 'symbol', 'secret'), key=lambda k: loot[k])
        return max(('coal', 'food'), key=lambda k: loot[k] / (need[k] + 0.05))


def summarize(policy, n, places):
    ends = Counter(); agg = defaultdict(float); arrive = []
    for i in range(n):
        run = FirstLeg(2000 + i, policy, places).play()
        ends[run.end] += 1
        for k, v in run.stats.items():
            agg[k] += v
        agg['end_food'] += run.food; agg['end_med'] += run.med
        arrive.append(run.coal)
    arrive.sort()
    print(f'\n## {policy} ({n}판)')
    print('끝:', ', '.join(f'{k} {v / n:.0%}' for k, v in ends.most_common()))
    print(f'도착 석탄: 평균 {sum(arrive) / n:.1f}, 하위 10% {arrive[n // 10]:.1f}, 최저 {arrive[0]:.1f}')
    keys = ['min_coal', 'low_coal_segments', 'emergency_used', 'end_food', 'end_med', 'starving_segments', 'deaths',
            'no_death_by_guben', 'strikes', 'target_coal', 'target_food', 'target_medicine', 'passed_stops',
            'coal_from_술레후프', 'coal_from_발전소', 'coal_from_팔켄베르크', 'lignite_segments',
            'water_fire', 'water_snow', 'water_skip', 'shift_relief']
    print('평균:', ', '.join(f'{k} {agg[k] / n:.2f}' for k in keys))


def main():
    n = 1000
    args = sys.argv[1:]
    P.update(FIRST)
    if '--hot' in args:
        args.remove('--hot'); P['hot_water'] = 0.5
    if args and args[0].isdigit():
        n = int(args.pop(0))
    if args and args[0] == '--tune':
        for kv in args[1:]:
            k, v = kv.split('=')
            P[k] = float(v) if isinstance(P[k], float) else int(v)
    places = S.load_places()
    print('설정:', {k: P[k] for k in ('coal0', 'food0', 'haul_total', 'lever_line', 'hot_water')})
    for policy in ('passive', 'caretaker', 'schemer'):
        summarize(policy, n, places)


if __name__ == '__main__':
    main()
