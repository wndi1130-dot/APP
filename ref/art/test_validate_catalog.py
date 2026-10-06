"""Regression tests for research metadata; never execute Blender or use the network."""
from __future__ import annotations
import contextlib
import copy
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import validate_catalog as catalog


class CatalogTests(unittest.TestCase):
    def setUp(self) -> None:
        self.data = json.loads(catalog.INDEX.read_text(encoding="utf-8"))

    def validate(self, data: dict) -> None:
        with tempfile.TemporaryDirectory(prefix="app_catalog_test_") as temporary:
            path = Path(temporary) / "index.json"
            path.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
            with patch.object(catalog, "INDEX", path), contextlib.redirect_stdout(io.StringIO()):
                catalog.main()

    def test_actual_catalog_and_guidance(self) -> None:
        self.validate(self.data)

    def test_duplicate_resource_is_rejected(self) -> None:
        self.data["resources"].append(copy.deepcopy(self.data["resources"][0]))
        with self.assertRaisesRegex(ValueError, "Duplicate ID"):
            self.validate(self.data)

    def test_invented_runtime_test_is_rejected(self) -> None:
        self.data["resources"][0]["project_runtime_tested"] = True
        with self.assertRaisesRegex(ValueError, "Unsubstantiated runtime test"):
            self.validate(self.data)

    def test_invalid_source_is_rejected(self) -> None:
        self.data["resources"][0]["sources"] = ["file:///secret.txt"]
        with self.assertRaisesRegex(ValueError, "Invalid source URL"):
            self.validate(self.data)

    def test_empty_required_field_is_rejected(self) -> None:
        self.data["resources"][0]["next_test"] = ""
        with self.assertRaisesRegex(ValueError, "Missing next_test"):
            self.validate(self.data)

    def test_unknown_status_is_rejected(self) -> None:
        self.data["resources"][0]["status"] = "VERIFIED"
        with self.assertRaisesRegex(ValueError, "Invalid status"):
            self.validate(self.data)

    def test_reused_excluded_id_is_rejected(self) -> None:
        self.data["excluded"][0]["id"] = self.data["resources"][0]["id"]
        with self.assertRaisesRegex(ValueError, "Duplicate excluded ID"):
            self.validate(self.data)


if __name__ == "__main__":
    unittest.main()
