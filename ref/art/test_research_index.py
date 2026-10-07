"""Regression tests for the research index. No asset execution or network access."""
import copy
import unittest

import build_research_index as index


class ResearchIndexTests(unittest.TestCase):
    def setUp(self):
        self.catalogs = index.load()

    def test_actual_catalogs_and_generated_documents(self):
        root = (index.ROOT / "README.md").read_text(encoding="utf-8")
        outputs, counts = index.render(self.catalogs, root)
        self.assertEqual(counts["total_resource_entries"], 62)
        self.assertEqual(counts["v4_resources"], 8)
        self.assertGreater(index.check_outputs(outputs), 0)

    def test_duplicate_across_versions_is_rejected(self):
        self.catalogs[2]["resources"].append(copy.deepcopy(self.catalogs[0]["resources"][0]))
        with self.assertRaisesRegex(ValueError, "Duplicate resource ID"):
            index.validate(self.catalogs)

    def test_unsubstantiated_runtime_is_rejected(self):
        self.catalogs[2]["resources"][0]["project_runtime_tested"] = True
        with self.assertRaisesRegex(ValueError, "Unsubstantiated runtime claim"):
            index.validate(self.catalogs)

    def test_unknown_source_reference_is_rejected(self):
        self.catalogs[2]["resources"][0]["source_ids"] = ["UNKNOWN"]
        with self.assertRaisesRegex(ValueError, "Unknown source reference"):
            index.validate(self.catalogs)

    def test_missing_license_is_rejected(self):
        self.catalogs[2]["resources"][0]["license"] = ""
        with self.assertRaisesRegex(ValueError, "Missing license"):
            index.validate(self.catalogs)

    def test_recheck_requires_existing_target(self):
        self.catalogs[2]["rechecks"][0]["updates_resource"] = "does_not_exist"
        with self.assertRaisesRegex(ValueError, "Unknown recheck target"):
            index.validate(self.catalogs)

    def test_local_path_cannot_be_source_url(self):
        self.catalogs[2]["sources"]["S01"]["url"] = "file:///secret.txt"
        with self.assertRaisesRegex(ValueError, "Invalid source URL"):
            index.validate(self.catalogs)

    def test_stale_readme_is_rejected(self):
        root = (index.ROOT / "README.md").read_text(encoding="utf-8")
        outputs, _ = index.render(self.catalogs, root)
        outputs["ref/art/README.md"] += "stale\n"
        with self.assertRaisesRegex(ValueError, "Stale generated file"):
            index.check_outputs(outputs)


if __name__ == "__main__":
    unittest.main()
