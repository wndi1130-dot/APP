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
        self.assertEqual(counts["total_resource_entries"], 85)
        self.assertEqual(counts["v4_resources"], 8)
        self.assertEqual(counts["v5_resources"], 9)
        self.assertEqual(counts["v6_resources"], 14)
        self.assertEqual(counts["v6_action_groups"], 10)
        self.assertEqual(counts["v6_rechecks"], 1)
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

    def test_http_reference_requires_explicit_note(self):
        self.catalogs[3]["sources"]["S01"]["transport_note"] = ""
        with self.assertRaisesRegex(ValueError, "Invalid source URL"):
            index.validate(self.catalogs)

    def test_http_exception_does_not_allow_other_hosts(self):
        self.catalogs[3]["sources"]["S01"]["url"] = "http://example.org/untrusted"
        with self.assertRaisesRegex(ValueError, "Invalid source URL"):
            index.validate(self.catalogs)

    def test_new_exclusion_cannot_reuse_resource_id(self):
        self.catalogs[3]["excluded"][0]["id"] = self.catalogs[0]["resources"][0]["id"]
        with self.assertRaisesRegex(ValueError, "Excluded ID collision"):
            index.validate(self.catalogs)

    def test_v5_does_not_claim_asset_package_download(self):
        self.catalogs[3]["resources"][0]["package_downloaded"] = True
        with self.assertRaisesRegex(ValueError, "Unsubstantiated execution claim"):
            index.validate(self.catalogs)

    def test_v6_clip_requires_supported_evidence_level(self):
        self.catalogs[4]["resources"][0]["clips"][0]["evidence"] = "played_in_blender"
        with self.assertRaisesRegex(ValueError, "Unsubstantiated clip evidence"):
            index.validate(self.catalogs)

    def test_v6_clip_requires_source(self):
        self.catalogs[4]["resources"][0]["clips"][0]["source_ids"] = ["MISSING"]
        with self.assertRaisesRegex(ValueError, "Unknown clip source"):
            index.validate(self.catalogs)

    def test_v6_duplicate_clip_is_rejected(self):
        clips = self.catalogs[4]["resources"][0]["clips"]
        clips.append(copy.deepcopy(clips[0]))
        with self.assertRaisesRegex(ValueError, "Duplicate or missing clip"):
            index.validate(self.catalogs)

    def test_v6_coverage_cannot_invent_resource(self):
        self.catalogs[4]["coverage"][0]["resource_ids"] = ["imaginary_amputation_pack"]
        with self.assertRaisesRegex(ValueError, "Unknown coverage resource"):
            index.validate(self.catalogs)

    def test_v6_exclusion_cannot_reuse_resource_id(self):
        self.catalogs[4]["excluded"][0]["id"] = self.catalogs[0]["resources"][0]["id"]
        with self.assertRaisesRegex(ValueError, "Duplicate supplementary ID"):
            index.validate(self.catalogs)

    def test_v6_missing_gap_is_rejected(self):
        self.catalogs[4]["coverage"][0]["gap"] = ""
        with self.assertRaisesRegex(ValueError, "Missing coverage gap"):
            index.validate(self.catalogs)

    def test_stale_readme_is_rejected(self):
        root = (index.ROOT / "README.md").read_text(encoding="utf-8")
        outputs, _ = index.render(self.catalogs, root)
        outputs["ref/art/README.md"] += "stale\n"
        with self.assertRaisesRegex(ValueError, "Stale generated file"):
            index.check_outputs(outputs)


if __name__ == "__main__":
    unittest.main()
