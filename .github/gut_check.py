# rust-exception: existing — the CI's GUT pass check was inline Python in s2-android.yml; this is that check, testable
"""Pass a GUT shard only when its JUnit report is whole and clean.

    python3 .github/gut_check.py <gut-shard.txt> <gut-results.xml> <gut.log>

- Every `func test_…` of every script in the shard must be in the report under that script. A script GUT
  could not load (a parse error, a call to a removed function) drops out of the report and GUT's own
  summary still says 0 failing; a whole-shard count could also be covered by another script's extra cases.
- No case may carry a failure, error or skipped mark, or a status other than "pass".
- The run log may not hold a `SCRIPT ERROR:` line: a runtime script error inside a test does not by itself
  fail the test in GUT. (Engine `ERROR:` lines are not counted; some tests write broken files on purpose.)
Exit 0 with one summary line, or exit 1 with every problem listed.
"""
import pathlib
import re
import sys
import xml.etree.ElementTree as ET

TEST_FUNC = re.compile(r'(?m)^func\s+(test_\w+)\s*\(')
SCRIPT_ERROR = re.compile(r'(?m)^SCRIPT ERROR:.*$')
RES = 'res://'


def expected_tests(sources):
    """{script: set of test function names} from {script: source}; script keys without res://."""
    return {script: set(TEST_FUNC.findall(text)) for script, text in sources.items()}


def problems(sources, report_xml, log):
    """Every reason this shard does not pass (empty list = pass). Pure: no files."""
    out = []
    try:
        root = ET.fromstring(report_xml)
    except ET.ParseError as e:
        return [f'GUT report is not readable XML: {e}']
    reported = {}
    for case in root.iter('testcase'):
        script = case.get('classname') or ''
        name = case.get('name') or ''
        reported.setdefault(script, set()).add(name)
        marks = [child.tag for child in case if child.tag in ('failure', 'error', 'skipped')]
        status = case.get('status', '')
        if marks or status != 'pass':
            out.append(f'{script} {name}: {", ".join(marks) or "status " + (status or "missing")}')
    expected = expected_tests(sources)
    if not expected or not any(expected.values()):
        out.append('this shard has no test functions')
    for script, names in sorted(expected.items()):
        got = reported.get(script)
        if names and got is None:
            out.append(f'{script}: not in the report (GUT did not load it) — {len(names)} tests missing')
            continue
        missing = sorted(names - (got or set()))
        if missing:
            out.append(f'{script}: {len(missing)} tests missing from the report: {", ".join(missing[:8])}'
                       + (' …' if len(missing) > 8 else ''))
    errors = SCRIPT_ERROR.findall(log)
    for line in errors[:20]:
        out.append(f'script error in the run log: {line.strip()[:200]}')
    if len(errors) > 20:
        out.append(f'… {len(errors) - 20} more script errors in the run log')
    return out


def main(argv):
    if len(argv) != 3:
        print('usage: gut_check.py <gut-shard.txt> <gut-results.xml> <gut.log>', file=sys.stderr)
        return 2
    shard, report, log = (pathlib.Path(a) for a in argv)
    scripts = [s[len(RES):] if s.startswith(RES) else s for s in shard.read_text(encoding='utf-8').split()]
    sources = {s: (pathlib.Path('s2') / s).read_text(encoding='utf-8') for s in scripts}
    found = problems(sources, report.read_text(encoding='utf-8') if report.exists() else '',
                     log.read_text(encoding='utf-8', errors='replace') if log.exists() else '')
    if found:
        print(f'GUT check failed ({len(found)}):')
        for p in found:
            print(f'  {p}')
        return 1
    total = sum(len(n) for n in expected_tests(sources).values())
    print(f'GUT report: {total} passing test cases in {len(scripts)} scripts, every test function reported, '
          f'0 script errors')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
