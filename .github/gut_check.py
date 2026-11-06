# rust-exception: existing — the CI's GUT pass check was inline Python in s2-android.yml; this is that check, testable
"""Pass a GUT shard only when its JUnit report is whole and clean.

    python3 .github/gut_check.py <gut-shard.txt> <gut-results.xml> <gut.log>

- Every script in the shard must declare at least one top-level `func test_…` (outside strings and
  comments), and every one of them must be in the report under that script. A script GUT could not load
  (a parse error, a call to a removed function) drops out of the report and GUT's own summary still says
  0 failing; a whole-shard count could also be covered by another script's extra cases.
- Inner test classes (`class X extends GutTest`) are refused rather than guessed at: GUT reports them
  under its own names, and this check does not map them yet. main has none (2026-11-07).
- No case may carry a failure, error or skipped mark, or a status other than "pass".
- The run log must exist and may not hold `SCRIPT ERROR:` anywhere on a line (colour codes stripped): a
  runtime script error inside a test does not by itself fail the test in GUT, and GUT's stdout and the
  engine's stderr share one pipe, so the text can land mid-line. Engine `ERROR:` lines are not counted;
  some tests write broken files on purpose (34 such lines a main run, 2026-11-07).
Exit 0 with one summary line, 1 with every problem listed, 2 for wrong arguments.
"""
import pathlib
import re
import sys
import xml.etree.ElementTree as ET

STRINGS = re.compile(r'"""[\s\S]*?"""|\'\'\'[\s\S]*?\'\'\'')
TEST_FUNC = re.compile(r'(?m)^func\s+(test_\w+)\s*\(')
INNER_TEST_CLASS = re.compile(r'(?m)^class\s+\w+\s+extends\s+(?:GutTest\b|"res://addons/gut/test\.gd")')
ANSI = re.compile(r'\x1b\[[0-9;?]*[A-Za-z]')
SCRIPT_ERROR = re.compile(r'SCRIPT ERROR:.*')
RES = 'res://'


def _code(source):
    """Source without multi-line strings, so a function written inside one is not a test."""
    return STRINGS.sub('', source)


def expected_tests(sources):
    """{script: set of top-level test function names} from {script: source}; script keys without res://."""
    return {script: set(TEST_FUNC.findall(_code(text))) for script, text in sources.items()}


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
    if not sources:
        out.append('this shard has no test scripts')
    expected = expected_tests(sources)
    for script, names in sorted(expected.items()):
        if INNER_TEST_CLASS.search(_code(sources[script])):
            out.append(f'{script}: has an inner test class — gut_check.py does not map those yet')
        if not names:
            out.append(f'{script}: no top-level `func test_` — every test script must declare one')
            continue
        got = reported.get(script)
        if got is None:
            out.append(f'{script}: not in the report (GUT did not load it) — {len(names)} tests missing')
            continue
        missing = sorted(names - got)
        if missing:
            out.append(f'{script}: {len(missing)} tests missing from the report: {", ".join(missing[:8])}'
                       + (' …' if len(missing) > 8 else ''))
    errors = SCRIPT_ERROR.findall(ANSI.sub('', log))
    for line in errors[:20]:
        out.append(f'script error in the run log: {line.strip()[:200]}')
    if len(errors) > 20:
        out.append(f'… {len(errors) - 20} more script errors in the run log')
    return out


def summary(sources, report_xml):
    """The pass line: test functions checked and cases in the report (they differ if a test reports twice)."""
    functions = sum(len(n) for n in expected_tests(sources).values())
    cases = sum(1 for _ in ET.fromstring(report_xml).iter('testcase'))
    return (f'GUT report: {functions} test functions in {len(sources)} scripts all reported and passing '
            f'({cases} cases), 0 script errors')


def main(argv):
    if len(argv) != 3:
        print('usage: gut_check.py <gut-shard.txt> <gut-results.xml> <gut.log>', file=sys.stderr)
        return 2
    shard, report, log = (pathlib.Path(a) for a in argv)
    missing = [str(p) for p in (shard, report, log) if not p.is_file()]
    if missing:
        print(f'GUT check failed: missing {", ".join(missing)} (no report or run log means nothing was checked)')
        return 1
    scripts = [s[len(RES):] if s.startswith(RES) else s for s in shard.read_text(encoding='utf-8').split()]
    sources = {s: (pathlib.Path('s2') / s).read_text(encoding='utf-8-sig') for s in scripts}
    report_xml = report.read_text(encoding='utf-8')
    found = problems(sources, report_xml, log.read_text(encoding='utf-8', errors='replace'))
    if found:
        print(f'GUT check failed ({len(found)}):')
        for p in found:
            print(f'  {p}')
        return 1
    print(summary(sources, report_xml))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
