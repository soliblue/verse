import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from db.environment import load_environment
from server.config import ServerConfig


class ConfigurationTests(unittest.TestCase):
    def test_authentication_is_required_by_default(self):
        with patch.dict(os.environ, {}, clear=True):
            with self.assertRaisesRegex(ValueError, "MORROW_DEVICE_SECRET is required"):
                ServerConfig.environment()

    def test_unauthenticated_mode_is_explicit(self):
        with patch.dict(os.environ, {"MORROW_ALLOW_UNAUTHENTICATED": "1"}, clear=True):
            self.assertTrue(ServerConfig.environment().allow_unauthenticated)

    def test_short_device_secret_is_rejected(self):
        with patch.dict(os.environ, {"MORROW_DEVICE_SECRET": "too-short"}, clear=True):
            with self.assertRaisesRegex(ValueError, "at least 24 characters"):
                ServerConfig.environment()

    def test_placeholder_device_secret_is_rejected(self):
        with patch.dict(
            os.environ,
            {"MORROW_DEVICE_SECRET": "replace-with-a-long-random-device-secret"},
            clear=True,
        ):
            with self.assertRaisesRegex(ValueError, "placeholder"):
                ServerConfig.environment()

    def test_environment_file_is_loaded_without_overwriting_process_values(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / ".env"
            path.write_text(
                "MORROW_DEVICE_SECRET=file-secret-with-enough-characters\nMORROW_PORT=9999\n",
                encoding="utf-8",
            )
            with patch.dict(os.environ, {"MORROW_PORT": "8787"}, clear=True):
                load_environment(path)
                self.assertEqual(os.environ["MORROW_DEVICE_SECRET"], "file-secret-with-enough-characters")
                self.assertEqual(os.environ["MORROW_PORT"], "8787")


if __name__ == "__main__":
    unittest.main()
