"""Regression tests for evidence boundaries in the UI research dossier."""
import unittest
import validate_research as research


class ResearchTests(unittest.TestCase):
    def setUp(self):
        self.registry, self.matrix, self.capture = research.load()

    def validate(self):
        return research.validate_data(self.registry, self.matrix, self.capture)

    def test_current_dossier(self):
        counts = self.validate()
        self.assertEqual(counts["source_records"], 37)
        self.assertEqual(counts["event_proposals"], 24)
        self.assertEqual(counts["sound_cue_intents"], 20)
        self.assertGreater(research.validate_documents(), 0)

    def test_duplicate_source_rejected(self):
        self.registry["sources"][1]["id"] = self.registry["sources"][0]["id"]
        with self.assertRaisesRegex(ValueError, "Duplicate source ID"):
            self.validate()

    def test_missing_rights_rejected(self):
        self.registry["sources"][0]["rights"] = ""
        with self.assertRaisesRegex(ValueError, "Missing source rights"):
            self.validate()

    def test_unknown_event_source_rejected(self):
        self.matrix["events"][0]["inspiration_sources"] = ["G99"]
        with self.assertRaisesRegex(ValueError, "Unknown event source"):
            self.validate()

    def test_invented_playback_rejected(self):
        self.registry["sources"][0]["audio_listened"] = True
        with self.assertRaisesRegex(ValueError, "Unsubstantiated source execution"):
            self.validate()

    def test_analyst_not_reclassified_as_developer(self):
        next(s for s in self.registry["sources"] if s["id"] == "G10")["kind"] = "developer_breakdown"
        with self.assertRaisesRegex(ValueError, "Independent analysis reclassified"):
            self.validate()

    def test_proposal_not_misrepresented_as_original(self):
        self.matrix["events"][0]["evidence_level"] = "original_observation"
        with self.assertRaisesRegex(ValueError, "Proposal misrepresented"):
            self.validate()

    def test_invented_sound_file_rejected(self):
        self.matrix["sound_cues"][0]["selected_audio_file"] = "original_click.wav"
        with self.assertRaisesRegex(ValueError, "Unsubstantiated selected audio"):
            self.validate()

    def test_unsupported_checkpoint_rejected(self):
        self.capture["checkpoints"][0]["start_seconds"] = 123
        with self.assertRaisesRegex(ValueError, "Unsupported or duplicate checkpoint"):
            self.validate()

    def test_invented_missing_timestamp_rejected(self):
        self.capture["missing_original_checks"][0]["timestamp_start"] = 30
        with self.assertRaisesRegex(ValueError, "Invented original observation"):
            self.validate()

    def test_invalid_duration_rejected(self):
        self.matrix["events"][0]["duration_ms_proposal"] = [-1, 100]
        with self.assertRaisesRegex(ValueError, "Invalid proposed duration"):
            self.validate()

    def test_source_url_with_credentials_rejected(self):
        self.registry["sources"][0]["url"] = "https://user:pass@example.org/"
        with self.assertRaisesRegex(ValueError, "Invalid source URL"):
            self.validate()


if __name__ == "__main__":
    unittest.main()
