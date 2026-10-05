"""Offline regression tests against independently transcribed NIKL examples."""

from __future__ import annotations

from collections import Counter
import json
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch
import unicodedata

ROOT = Path(__file__).resolve().parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))
import transliterate as module


class OfficialExamplesTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.examples = json.loads((ROOT / "nikl_examples.json").read_text(encoding="utf-8"))["examples"]

    def test_minimum_official_examples_per_language(self):
        counts = Counter(item["language"] for item in self.examples)
        for language in ("pl", "de", "cz", "hu"):
            self.assertGreaterEqual(counts[language], 20, language)

    def test_examples_have_independent_source_pairs(self):
        seen = set()
        for item in self.examples:
            with self.subTest(language=item["language"], original=item["original"]):
                key = item["language"], unicodedata.normalize("NFC", item["original"]).casefold()
                self.assertNotIn(key, seen)
                seen.add(key)
                self.assertTrue(item["source"].startswith("https://www.korean.go.kr/"))
                self.assertIn(item["original"], item["source_line"])
                self.assertIn(item["korean"], item["source_line"])
                self.assertRegex(item["korean"], r"[가-힣]")

    def test_raw_rules_without_lookup_match_all_official_examples(self):
        # A matching lookup table is not evidence that a converter works.
        # Break that lookup deliberately, then exercise the actual rule engine.
        with patch.object(module, "_examples", side_effect=AssertionError("용례 조회를 사용하면 안 됩니다.")):
            for item in self.examples:
                with self.subTest(language=item["language"], original=item["original"]):
                    actual = module.transliterate_rules(item["original"], item["language"])
                    self.assertEqual(actual, item["korean"])

    def test_attested_spellings_take_priority_over_rule_result(self):
        with patch.object(module, "transliterate_rules", side_effect=AssertionError("용례가 우선입니다.")):
            for item in self.examples:
                with self.subTest(original=item["original"]):
                    result = module.transcribe(item["original"], item["language"])
                    self.assertEqual(result["korean"], item["korean"])
                    self.assertEqual(result["korean_basis"], "용례")
                    self.assertEqual(result["korean_source"], item["source"])

    def test_source_typos_are_not_silently_certified(self):
        keys = {(x["language"], x["original"]) for x in self.examples}
        for key in (("pl", "przjyaciół"), ("cz", "sěst"), ("de", "auβerhalb")):
            self.assertNotIn(key, keys)


class ConverterTests(unittest.TestCase):
    def test_requested_proper_names_are_rule_based_holdouts(self):
        examples = module._examples()
        cases = [("de", "Leipzig", "라이프치히"),
                 ("cz", "Krejčí", "크레이치"),
                 ("pl", "Mazurek", "마주레크")]
        for language, original, expected in cases:
            with self.subTest(original=original):
                self.assertNotIn((language, module._key(original)), examples)
                self.assertEqual(module.transliterate_rules(original, language), expected)
                self.assertEqual(module.transcribe(original, language)["korean_basis"], "규칙")

    def test_surname_gender_variants(self):
        cases = [("pl", "Kowalski", "코발스키"), ("pl", "Kowalska", "코발스카"),
                 ("pl", "Nowak", "노바크"), ("cz", "Novák", "노바크"),
                 ("cz", "Nováková", "노바코바")]
        for language, original, expected in cases:
            with self.subTest(original=original):
                self.assertEqual(module.transliterate_rules(original, language), expected)

    def test_unicode_normalization_and_case(self):
        for language, word in (("cz", "Krejčí"), ("de", "Müller"), ("pl", "Rzeszów"),
                               ("hu", "Kovács"), ("uk", "Олександр"), ("lt", "Žukauskas")):
            with self.subTest(language=language):
                expected = module.transliterate_rules(word, language)
                self.assertEqual(module.transliterate_rules(unicodedata.normalize("NFD", word), language), expected)
                self.assertEqual(module.transliterate_rules(word.upper(), language), expected)
                self.assertEqual(expected, unicodedata.normalize("NFC", expected))

    def test_language_aliases(self):
        for alias in ("cs", "ces", "cze", "cz"):
            self.assertEqual(module.transliterate_rules("Krejčí", alias), "크레이치")

    def test_whitespace_and_hyphen(self):
        self.assertEqual(module.transliterate_rules("  Herr   Schiller  ", "de"), "헤어 실러")
        self.assertEqual(module.transliterate_rules("Herr-Schiller", "de"), "헤어-실러")

    def test_unverified_language_is_never_labeled_as_nikl_rule(self):
        for language, name in (("uk", "Олександр"), ("lt", "Jonas"), ("sk", "Ján")):
            with self.subTest(language=language):
                result = module.transcribe(name, language)
                self.assertEqual(result["korean_basis"], "미확인")
                self.assertRegex(result["korean"], r"[가-힣]")
                self.assertIn("미확인", result["korean_basis"])

    def test_hungarian_rules_exist_and_are_used(self):
        result = module.transcribe("János", "hu")
        self.assertEqual(result["korean"], "야노시")
        self.assertEqual(result["korean_basis"], "규칙")
        self.assertTrue(result["korean_source"].endswith("P000135"))

    def test_pronunciation_evidence_does_not_become_nikl_attestation(self):
        for original, korean in (("David", "다비트"), ("Charlotte", "샤를로테"), ("Louis", "루이")):
            with self.subTest(original=original):
                result = module.transcribe(original, "de")
                self.assertEqual(result["korean"], korean)
                self.assertEqual(result["korean_basis"], "규칙")
                self.assertIn("duden.de", result["pronunciation_source"])
        self.assertEqual(module.transcribe("Joshua", "de")["korean_basis"], "미확인")
        self.assertEqual(module.transcribe("Zeynep", "de")["korean_basis"], "미확인")
        self.assertEqual(module.transcribe("Joshua Schmidt", "de")["korean_basis"], "미확인")
        self.assertEqual(module.transcribe("Zeynep-Maria", "de")["korean_basis"], "미확인")

    def test_invalid_input_is_rejected(self):
        for text in (None, "", " ", "123", "a\x00b", "a\ue000b", "a" * 201,
                     "Anna\nMaria", "Anna_1", "<script>", "A?B"):
            with self.subTest(text=text), self.assertRaises(ValueError):
                module.transliterate_rules(text, "pl")
        with self.assertRaises(ValueError):
            module.transliterate_rules("Anna", "xx")
        with self.assertRaises(ValueError):
            module.transliterate_rules("한글", "pl")

    def test_deterministic_and_stateless(self):
        expected = module.transliterate_rules("Krejčí", "cz")
        for _ in range(20):
            module.transliterate_rules("Mazurek", "pl")
            self.assertEqual(module.transliterate_rules("Krejčí", "cz"), expected)

    def test_stdlib_only_runtime_imports(self):
        import ast
        tree = ast.parse((ROOT / "transliterate.py").read_text(encoding="utf-8"))
        modules = []
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                modules.extend(alias.name.split(".")[0] for alias in node.names)
            if isinstance(node, ast.ImportFrom) and node.module:
                modules.append(node.module.split(".")[0])
        self.assertTrue(set(modules).issubset(sys.stdlib_module_names), modules)

    def test_cli_json_and_error_status(self):
        command = [sys.executable, "-X", "utf8", str(ROOT / "transliterate.py")]
        result = subprocess.run(command + ["de", "Leipzig"], capture_output=True, encoding="utf-8", check=True)
        self.assertEqual(json.loads(result.stdout)["korean"], "라이프치히")
        invalid = subprocess.run(command + ["xx", "Anna"], capture_output=True, encoding="utf-8")
        self.assertEqual(invalid.returncode, 1)
        self.assertIn("[FAIL]", invalid.stderr)


if __name__ == "__main__":
    unittest.main()
