set -euo pipefail
"$GODOT_BIN" --headless --path s2 --script addons/gut/gut_cmdln.gd \
  -gdir=res://tests -ginclude_subdirs -gexit \
  -gjunit_xml_file=res://build/gut-results.xml 2>&1 | tee s2/build/gut.log
# Require a real nonempty passing test report, even if runner exits zero.
python3 - <<'PY'
import xml.etree.ElementTree as ET
report = ET.parse('s2/build/gut-results.xml').getroot()
cases = list(report.iter('testcase'))
if len(cases) < 9 or any(list(case.iter('failure')) or list(case.iter('error')) or list(case.iter('skipped')) for case in cases):
    raise SystemExit('Missing, failed, errored or skipped GUT tests')
print(f'GUT report: {len(cases)} passing test cases')
PY
