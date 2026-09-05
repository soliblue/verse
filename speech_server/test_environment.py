import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from speech_server.environment import DEFAULT_ENVIRONMENT_FILE, load_environment


class EnvironmentTests(unittest.TestCase):
    def test_root_location(self):
        self.assertEqual(DEFAULT_ENVIRONMENT_FILE, Path(__file__).resolve().parents[1] / ".env")

    def test_values_and_existing_environment(self):
        with tempfile.TemporaryDirectory() as directory, patch.dict(os.environ, {"KEEP": "existing"}, clear=True):
            path = Path(directory) / ".env"
            path.write_text("# private\nexport TOKEN='test value'\nKEEP=replaced\n", encoding="utf-8")
            load_environment(path)
            self.assertEqual(os.environ["TOKEN"], "test value")
            self.assertEqual(os.environ["KEEP"], "existing")

    def test_missing_file_and_invalid_entry(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / ".env"
            load_environment(path)
            path.write_text("not a variable", encoding="utf-8")
            with self.assertRaises(ValueError):
                load_environment(path)
