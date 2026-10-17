"""문서 검사(로렌리뷰 2026-10-18 프로토타입). 로컬과 CI에서 같은 명령으로 돈다.

  python3 tools/check_docs.py --base <기준 커밋> [--head <커밋, 기본 HEAD>]

1. 새로 더한 줄의 「결정 NNN」은 docs/design/decisions.md 에 그 번호가 적혀 있어야 한다.
   번호만 쓰고 장부에 안 적으면 다음 세션이 그 결정을 찾을 수 없다. 이미 있는 줄은 보지 않는다.
2. 문서에 손으로 적는 시험 수(「GUT 시험은 N개」 같은 줄)를 새로 더하지 않는다. CI가 실제 수를 센다.
"""
import argparse, re, subprocess, sys

DECISIONS = "docs/design/decisions.md"
CITE = re.compile(r"결정 (\d{3})")
TEST_COUNT = re.compile(r"(시험|테스트)(은|는|이|가)? *[0-9][0-9,]{2,} *개")


def git(*args):
    r = subprocess.run(["git", *args], capture_output=True, text=True, encoding="utf-8", errors="replace")
    if r.returncode != 0:
        sys.exit(f"git {' '.join(args)} 실패: {r.stderr.strip()}")
    return r.stdout


def added_lines(base, head):
    diff = git("diff", "--unified=0", "--no-color", f"{base}..{head}", "--", "*.md", "*.ts", "*.gd")
    path = None
    for line in diff.splitlines():
        if line.startswith("+++ "):
            path = line[6:] if line.startswith("+++ b/") else None
        elif line.startswith("+") and path:
            yield path, line[1:]


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--base", required=True)
    p.add_argument("--head", default="HEAD")
    a = p.parse_args()
    known = set(CITE.findall(git("show", f"{a.head}:{DECISIONS}")))
    errors = []
    for path, text in added_lines(a.base, a.head):
        for n in CITE.findall(text):
            if n not in known:
                errors.append(f"{path}: 결정 {n} 이 {DECISIONS} 에 없다. 확정 사항이나 검토 중인 제안 절에 「(… 사용자 결정, 결정 {n})」 줄을 같이 더한다.")
        if path.endswith(".md") and TEST_COUNT.search(text):
            errors.append(f"{path}: 시험 수를 문서에 손으로 적지 않는다(CI 'GUT report' 줄과 npm test 출력이 실제 수다). 줄: {text.strip()[:80]}")
    for e in dict.fromkeys(errors):
        print(e)
    if errors:
        sys.exit(1)
    print(f"check_docs: ok ({a.base}..{a.head})")


if __name__ == "__main__":
    main()
