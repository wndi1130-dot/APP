"""Validate data contracts, provenance, normalization and reproducibility."""

from __future__ import annotations

from collections import Counter
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import re
import sys
import unittest
import unicodedata
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))
from build_pools import build_outputs, make_language, serialize
from transliterate import transcribe


def load(name):
    return json.loads((ROOT / name).read_text(encoding="utf-8"))


class PoolTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.pools = {code: load(code + ".json") for code in ("pl", "de", "cz", "other")}

    def parts(self):
        for code, pool in self.pools.items():
            for name in pool["given_names"]:
                yield name.get("language", code), name, "given"
            for surname in pool["surnames"]:
                for part in ([surname["male"], surname["female"]] if "male" in surname else [surname]):
                    yield part.get("language", code), part, "surname"

    def test_required_files_and_loader_keys(self):
        for code, pool in self.pools.items():
            with self.subTest(code=code):
                self.assertEqual(pool["language"], code)
                self.assertIsInstance(pool["given_names"], list)
                self.assertIsInstance(pool["surnames"], list)
                self.assertTrue(pool["given_names"])
                self.assertTrue(pool["surnames"])

    def test_core_counts_and_gender_balance(self):
        for code in ("pl", "de", "cz"):
            pool = self.pools[code]
            self.assertGreaterEqual(len(pool["given_names"]), 150)
            self.assertGreaterEqual(len(pool["surnames"]), 200)
            genders = Counter(x["gender"] for x in pool["given_names"])
            self.assertEqual(set(genders), {"male", "female"})
            self.assertGreaterEqual(min(genders.values()) / sum(genders.values()), 0.4)

    def test_other_counts_per_language(self):
        pool = self.pools["other"]
        for language in ("uk", "sk", "hu", "lt"):
            given = [x for x in pool["given_names"] if x["language"] == language]
            surnames = [x for x in pool["surnames"] if x["language"] == language]
            self.assertGreaterEqual(len(given), 30, language)
            self.assertGreaterEqual(len(surnames), 39 if language == "lt" else 40, language)
            genders = Counter(x["gender"] for x in given)
            self.assertEqual(set(genders), {"male", "female"})
            self.assertGreaterEqual(min(genders.values()) / len(given), 0.4)

    def test_every_name_has_hangul_original_basis_and_source(self):
        for language, item, kind in self.parts():
            with self.subTest(language=language, original=item.get("original")):
                self.assertIsInstance(item["original"], str)
                self.assertTrue(item["original"].strip())
                self.assertEqual(item["original"], item["original"].strip())
                self.assertRegex(item["korean"], r"[가-힣]")
                self.assertNotRegex(item["korean"], r"[A-Za-z\u0400-\u052f?\ufffd]")
                self.assertIn(item["korean_basis"], {"용례", "규칙", "미확인"})
                if kind == "given":
                    self.assertIn(item["gender"], {"male", "female"})
                for key in ("source", "korean_source"):
                    parts = urlsplit(item[key])
                    self.assertIn(parts.scheme, {"http", "https"})
                    self.assertTrue(parts.netloc)
                for key in ("original", "korean"):
                    self.assertEqual(item[key], unicodedata.normalize("NFC", item[key]))

    def test_given_names_unique_within_language(self):
        seen = set()
        for language, item, kind in self.parts():
            if kind != "given":
                continue
            key = language, unicodedata.normalize("NFC", item["original"]).casefold()
            self.assertNotIn(key, seen, key)
            seen.add(key)

    def test_surname_roots_and_gender_forms_unique(self):
        seen = set()
        for code, pool in self.pools.items():
            for row in pool["surnames"]:
                language = row.get("language", code)
                for gender in ("male", "female"):
                    part = row[gender] if "male" in row else row
                    key = language, gender, unicodedata.normalize("NFC", part["original"]).casefold()
                    self.assertNotIn(key, seen, key)
                    seen.add(key)

    def test_required_surname_pairs(self):
        for code, male, female in (("pl", "Kowalski", "Kowalska"), ("cz", "Novák", "Nováková")):
            pairs = {(x["male"]["original"], x["female"]["original"])
                     for x in self.pools[code]["surnames"] if "male" in x}
            self.assertIn((male, female), pairs)
        for code in ("pl", "cz"):
            for item in self.pools[code]["surnames"]:
                if "male" in item or "female" in item:
                    self.assertIn("male", item)
                    self.assertIn("female", item)

    def test_given_and_surname_originals_do_not_overlap(self):
        given = {(language, unicodedata.normalize("NFC", item["original"]).casefold())
                 for language, item, kind in self.parts() if kind == "given"}
        surnames = {(language, unicodedata.normalize("NFC", item["original"]).casefold())
                    for language, item, kind in self.parts() if kind == "surname"}
        self.assertFalse(given & surnames, given & surnames)

    def test_lithuanian_consumer_forms_are_not_male_only_or_married_only(self):
        for surname in self.pools["other"]["surnames"]:
            if surname["language"] != "lt":
                continue
            self.assertIn("male", surname)
            self.assertIn("female", surname)
            self.assertEqual(surname["female"]["form_scope"], "traditional_unmarried")
            self.assertEqual(surname["female_form_usage"], "traditional_unmarried")
            self.assertEqual(surname["female_married"]["form_scope"], "traditional_married")
            self.assertRegex(surname["female_married"]["korean"], r"[가-힣]")

    def test_transcription_reproducible_and_attestation_not_invented(self):
        for language, item, _ in self.parts():
            with self.subTest(language=language, original=item["original"]):
                result = transcribe(item["original"], language)
                self.assertEqual(item["korean"], result["korean"])
                self.assertEqual(item["korean_basis"], result["korean_basis"])
                if language in ("uk", "sk", "lt"):
                    self.assertIn(item["korean_basis"], {"용례", "미확인"})

    def test_byte_identical_rebuild(self):
        for name, output in build_outputs().items():
            self.assertTrue((ROOT / name).read_bytes() == serialize(output), name)

    def test_utf8_without_bom_and_lf_json(self):
        for path in ROOT.glob("*.json"):
            raw = path.read_bytes()
            self.assertFalse(raw.startswith(b"\xef\xbb\xbf"), path.name)
            self.assertFalse(b"\r\n" in raw, path.name)
            self.assertTrue(raw.endswith(b"\n"), path.name)
            self.assertEqual(raw.decode("utf-8"), raw.decode("utf-8", errors="strict"))

    def test_source_seed_hashes_are_consistent(self):
        digest = hashlib.sha256((ROOT / "source_pools.json").read_bytes()).hexdigest()
        for pool in self.pools.values():
            self.assertEqual(pool["source_pools_sha256"], digest)

    def test_bad_seed_is_rejected_instead_of_silently_repaired(self):
        seed = load("source_pools.json")["pl"]
        bad = deepcopy(seed)
        bad["given_names"][1] = deepcopy(bad["given_names"][0])
        with self.assertRaises(ValueError):
            make_language("pl", bad)
        bad = deepcopy(seed)
        bad["given_names"][0]["gender"] = "unknown"
        with self.assertRaises(ValueError):
            make_language("pl", bad)
        bad = deepcopy(seed)
        bad["given_names"][0]["source"] = "확인하지 않은 출처"
        with self.assertRaises(ValueError):
            make_language("pl", bad)

    def test_existing_other_pool_limit_is_explicit(self):
        self.assertIn("A3", self.pools["other"]["integration_note"])
        self.assertIn("보장하지 못한다", self.pools["other"]["integration_note"])


class BlocklistTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.names = load("famous_blocklist.json")["names"]

    def test_hundreds_of_distinct_names(self):
        self.assertGreaterEqual(len(self.names), 300)
        originals = {unicodedata.normalize("NFC", x["original"]).casefold() for x in self.names}
        self.assertGreaterEqual(len(originals), 300)

    def test_aliases_are_not_counted_as_additional_people(self):
        identifiers = {x["qid"] for x in self.names}
        self.assertGreaterEqual(len(identifiers), 300)
        for identifier in identifiers:
            self.assertRegex(identifier, r"^Q\d+$")

    def test_required_fields_and_country_coverage(self):
        counts = Counter()
        counted = set()
        for item in self.names:
            with self.subTest(original=item.get("original")):
                self.assertTrue(item["original"].strip())
                self.assertRegex(item["korean"], r"[가-힣]")
                self.assertNotIn("?", item["original"])
                self.assertNotIn("?", item["korean"])
                self.assertIn(item["country"], {"pl", "de", "cz", "uk", "sk", "hu", "lt"})
                self.assertIn(urlsplit(item["source"]).scheme, {"http", "https"})
                self.assertTrue(urlsplit(item["source"]).netloc)
                self.assertEqual(item["korean_basis"], "미확인")
                self.assertTrue(item["korean_evidence"].startswith(("labels.", "aliases.", "sitelinks.")))
                if item["qid"] not in counted:
                    counted.add(item["qid"])
                    counts[item["country"]] += 1
        for language in ("pl", "de", "cz", "uk", "sk", "hu", "lt"):
            self.assertGreaterEqual(counts[language], 25, language)

    def test_variant_rows_have_canonical_people_and_no_cross_person_collision(self):
        base = {row["qid"]: row for row in self.names if "variant_of" not in row}
        self.assertGreaterEqual(len(base), 300)
        indexes = {"original": {}, "korean": {}}
        pairs = set()
        for row in self.names:
            if "variant_of" in row:
                self.assertEqual(row["variant_of"], row["qid"])
                self.assertIn(row["qid"], base)
                self.assertEqual(row["country"], base[row["qid"]]["country"])
            pair = []
            for field in ("original", "korean"):
                key = "".join(c for c in unicodedata.normalize("NFKD", row[field]).lower()
                              if not unicodedata.category(c).startswith("M") and not c.isspace())
                self.assertIn(indexes[field].get(key), (None, row["qid"]), (field, key))
                indexes[field][key] = row["qid"]
                pair.append(key)
            self.assertNotIn(tuple(pair), pairs)
            pairs.add(tuple(pair))


if __name__ == "__main__":
    unittest.main()
