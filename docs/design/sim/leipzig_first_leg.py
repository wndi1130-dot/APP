"""라이프치히 이탈을 실제 첫 구간(6구간) 위에서 본다 (설계 도구, 게임 코드가 아니다).

leipzig_split.py는 s1a의 24구간 판에 이탈 장면을 붙인다. 첫 구간은 정차 다섯 곳, 6구간이라
도착 관계가 크게 다르다. 그래서 first_leg_budget.py의 판(거리별 석탄, 갈탄, 급수탑, 정차마다 회기)에
같은 장면을 붙이고, 징후는 5구간 시작(라이프치히 두 구간 전)에 온다(first_leg_story.md 7.7).

사용: python3 -I docs/design/sim/leipzig_first_leg.py [판 수]
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import first_leg_budget as F  # noqa: E402
import leipzig_split as LS  # noqa: E402
import s1a_balance as S  # noqa: E402


class FirstLegSplit(LS.Leipzig, F.FirstLeg):
    pass


def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 1000
    S.P.update(F.FIRST)
    LS.L['omen_seg'] = F.FIRST['segments'] - 1
    LS.Leipzig = FirstLegSplit  # summarize가 이 이름으로 판을 만든다
    places = S.load_places()
    for policy in ('passive', 'caretaker', 'schemer'):
        LS.summarize(policy, n, places)


if __name__ == '__main__':
    main()
