# rust-exception: existing — tests the CI's Python GUT check (.github/gut_check.py) in the same language
"""python3 .github/test_gut_check.py — runs in CI before GUT so a broken check cannot wave a shard through."""
import pathlib
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import gut_check  # noqa: E402

A = 'tests/test_a.gd'
B = 'tests/game/test_b.gd'
SOURCES = {
    A: 'extends GutTest\n\nfunc test_one() -> void:\n\tpass\n\n\nfunc test_two(p = 1):\n\tpass\n\n\nfunc helper():\n\tpass\n',
    B: 'extends GutTest\n\n\nfunc test_three() -> void:\n\tpass\n',
}


def case(script, name, status='pass', mark=''):
    inner = f'<{mark} message="x"/>' if mark else ''
    return (f'<testcase name="{name}" assertions="1" status="{status}" classname="{script}" time="0">'
            f'{inner}</testcase>')


def report(*cases):
    """GUT's real nesting (main run 42296594400): testsuites > testsuite per script > testcase."""
    by_script = {}
    for c in cases:
        script = c.split('classname="', 1)[1].split('"', 1)[0]
        by_script.setdefault(script, []).append(c)
    suites = ''.join(f'<testsuite name="{s}" tests="{len(cs)}" failures="0" skipped="0" time="0">{"".join(cs)}</testsuite>'
                     for s, cs in by_script.items())
    return f'<?xml version="1.0" encoding="UTF-8"?><testsuites name="GutTests" failures="0" tests="{len(cases)}">{suites}</testsuites>'


WHOLE = report(case(A, 'test_one'), case(A, 'test_two'), case(B, 'test_three'))


class CheckTests(unittest.TestCase):
    def test_whole_clean_report_passes(self):
        self.assertEqual(gut_check.problems(SOURCES, WHOLE, 'Totals\nScripts 2\n'), [])

    def test_cases_are_read_inside_testsuite_elements(self):
        # A flat-children read of the root would see no cases here.
        self.assertIn('<testsuite ', WHOLE)
        found = gut_check.problems(SOURCES, report(case(A, 'test_one', status='fail'), case(A, 'test_two'),
                                                   case(B, 'test_three')), '')
        self.assertEqual(len(found), 1, found)

    def test_script_gut_could_not_load_fails(self):
        found = gut_check.problems(SOURCES, report(case(A, 'test_one'), case(A, 'test_two')), '')
        self.assertTrue(any(B in p and 'not in the report' in p for p in found), found)

    def test_missing_script_covered_by_extra_cases_still_fails(self):
        # The old whole-shard count (cases >= `func test_` lines) passed this: 3 cases for 3 functions,
        # though test_b.gd never ran.
        extra = report(case(A, 'test_one'), case(A, 'test_two'), case(A, 'test_two_more'))
        self.assertTrue(gut_check.problems(SOURCES, extra, ''))

    def test_one_missing_function_fails(self):
        found = gut_check.problems(SOURCES, report(case(A, 'test_one'), case(B, 'test_three')), '')
        self.assertEqual(len(found), 1, found)
        self.assertIn('test_two', found[0])

    def test_failure_error_skipped_or_other_status_fails(self):
        for kind in ('failure', 'error', 'skipped'):
            with self.subTest(kind=kind):
                bad = report(case(A, 'test_one', mark=kind), case(A, 'test_two'), case(B, 'test_three'))
                self.assertTrue(gut_check.problems(SOURCES, bad, ''))
        for status in ('fail', 'pending', 'risky', ''):
            with self.subTest(status=status):
                bad = report(case(A, 'test_one', status=status), case(A, 'test_two'), case(B, 'test_three'))
                self.assertTrue(gut_check.problems(SOURCES, bad, ''))

    def test_script_error_in_the_log_fails_wherever_it_sits(self):
        for log in ('SCRIPT ERROR: Invalid call. Nonexistent function \'gone\' in base \'Node\'.\n   at: x\n',
                    '* test_one  SCRIPT ERROR: Invalid call. Nonexistent function \'gone\'.\n',  # GUT text, same line
                    '   SCRIPT ERROR: Invalid call. Nonexistent function \'gone\'.\n',
                    '\x1b[31mSCRIPT ERROR: Invalid call. Nonexistent function \'gone\'.\x1b[0m\n',
                    'ok\x1b[0mSCRIPT ERROR: Invalid call. Nonexistent function \'gone\'.\n'):
            with self.subTest(log=log):
                found = gut_check.problems(SOURCES, WHOLE, log)
                self.assertEqual(len(found), 1, found)
                self.assertIn('Nonexistent function', found[0])

    def test_engine_error_lines_do_not_fail(self):
        # Tests that write broken files on purpose; the engine prints these on every main run.
        log = ("ERROR: user://test_train_warm_1.cfg_0.tscn:1 - Parse Error: Expected '['.\n"
               "ERROR: ConfigFile parse error at user://controls_test_1.cfg:3: Unexpected EOF while parsing simple tag.\n")
        self.assertEqual(gut_check.problems(SOURCES, WHOLE, log), [])

    def test_unreadable_or_empty_report_fails(self):
        for text in ('', '<testsuites', 'not xml'):
            with self.subTest(text=text):
                self.assertTrue(gut_check.problems(SOURCES, text, ''))

    def test_no_scripts_or_a_script_without_tests_fails(self):
        self.assertTrue(gut_check.problems({}, report(), ''))
        found = gut_check.problems({**SOURCES, 'tests/test_empty.gd': 'extends GutTest\n'}, WHOLE, '')
        self.assertEqual(len(found), 1, found)
        self.assertIn('test_empty.gd', found[0])

    def test_indented_commented_and_string_funcs_are_not_expected(self):
        src = {A: ('extends GutTest\nclass Fake extends RefCounted:\n\tfunc test_inner():\n\t\tpass\n'
                   '# func test_old():\nconst OLD = """\nfunc test_generated():\n\tpass\n"""\n'
                   "const OLD2 = '''\nfunc test_generated_two():\n'''\nfunc test_one():\n\tpass\n")}
        self.assertEqual(gut_check.problems(src, report(case(A, 'test_one')), ''), [])

    def test_inner_test_class_is_refused(self):
        for decl in ('class TestInner extends GutTest:', 'class TestInner extends "res://addons/gut/test.gd":'):
            with self.subTest(decl=decl):
                src = {A: f'extends GutTest\n{decl}\n\tfunc test_inner():\n\t\tpass\nfunc test_one():\n\tpass\n'}
                found = gut_check.problems(src, report(case(A, 'test_one')), '')
                self.assertTrue(any('inner test class' in p for p in found), found)

    def test_summary_counts_functions_and_cases_apart(self):
        twice = report(case(A, 'test_one'), case(A, 'test_one'), case(A, 'test_two'), case(B, 'test_three'))
        self.assertEqual(gut_check.problems(SOURCES, twice, ''), [])
        line = gut_check.summary(SOURCES, twice)
        self.assertIn('3 test functions in 2 scripts', line)
        self.assertIn('(4 cases)', line)


class MainTests(unittest.TestCase):
    """The command line: reads s2/<script> from the working directory, exit 0/1/2."""

    def run_main(self, files, shard_lines, xml, log, bom=False):
        with tempfile.TemporaryDirectory(prefix='gut check ') as root:
            base = pathlib.Path(root)
            for rel, text in files.items():
                p = base / 's2' / rel
                p.parent.mkdir(parents=True, exist_ok=True)
                p.write_text(('﻿' if bom else '') + text, encoding='utf-8')
            (base / 'shard.txt').write_text(''.join(f'res://{s}\n' for s in shard_lines), encoding='utf-8')
            if xml is not None:
                (base / 'r.xml').write_text(xml, encoding='utf-8')
            if log is not None:
                (base / 'gut.log').write_text(log, encoding='utf-8')
            return subprocess.run([sys.executable, str(pathlib.Path(gut_check.__file__)), 'shard.txt', 'r.xml', 'gut.log'],
                                  cwd=base, capture_output=True, text=True, timeout=60)

    def test_pass_and_fail_exit_codes(self):
        ok = self.run_main(SOURCES, [A, B], WHOLE, '')
        self.assertEqual(ok.returncode, 0, ok.stdout + ok.stderr)
        self.assertIn('3 test functions in 2 scripts', ok.stdout)
        bad = self.run_main(SOURCES, [A, B], report(case(A, 'test_one'), case(A, 'test_two')), '')
        self.assertEqual(bad.returncode, 1, bad.stdout + bad.stderr)
        self.assertIn(B, bad.stdout)

    def test_missing_report_or_log_fails(self):
        for xml, log in ((None, ''), (WHOLE, None)):
            with self.subTest(xml=xml is None, log=log is None):
                p = self.run_main(SOURCES, [A, B], xml, log)
                self.assertEqual(p.returncode, 1, p.stdout + p.stderr)
                self.assertIn('missing', p.stdout)

    def test_byte_order_mark_and_crlf_sources(self):
        crlf = {k: v.replace('\n', '\r\n') for k, v in SOURCES.items()}
        p = self.run_main(crlf, [A, B], WHOLE, '', bom=True)
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)

    def test_wrong_arguments(self):
        p = subprocess.run([sys.executable, str(pathlib.Path(gut_check.__file__))], capture_output=True, text=True, timeout=60)
        self.assertEqual(p.returncode, 2)


if __name__ == '__main__':
    unittest.main()
