import os
import shutil
import sqlite3
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from scripts.codex_app_thread import agent_environment, sandbox_policy
from scripts.nightjar_workspace import (
    backup_database,
    prepare_workspace,
    publish_workspace,
    restore_database,
    rollback_workspace,
    validate_workspace,
)


ROOT = Path(__file__).resolve().parents[1]


class NightjarAgentTests(unittest.TestCase):
    def test_agent_environment_excludes_server_secrets(self):
        with patch.dict(
            os.environ,
            {
                "HOME": "/tmp/home",
                "PATH": "/usr/bin",
                "CODEX_HOME": "/tmp/codex",
                "VERSE_DEVICE_SECRET": "private",
                "CLOUDFLARE_API_TOKEN": "private",
            },
            clear=True,
        ):
            environment = agent_environment()
        self.assertEqual(environment, {"CODEX_HOME": "/tmp/codex", "HOME": "/tmp/home", "PATH": "/usr/bin"})
        self.assertEqual(
            sandbox_policy("workspace-write", "/tmp/workspace"),
            {"type": "workspaceWrite", "writableRoots": ["/tmp/workspace"], "networkAccess": True},
        )

    def test_staged_first_edition_validates_and_materializes_explore(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "verse"
            root.mkdir()
            shutil.copytree(ROOT / "content", root / "content")
            workspace = Path(directory) / "workspace"
            prepare_workspace(root, workspace, None)

            result = validate_workspace(root, workspace, "2026-07-12")

            self.assertEqual(result["stories"], 10)
            self.assertGreater(result["citations"], 10)
            self.assertTrue((workspace / "content/explore/current.json").is_file())

    def test_publish_can_restore_the_previous_content(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "verse"
            root.mkdir()
            shutil.copytree(ROOT / "content", root / "content")
            original = (root / "content/preferences.md").read_bytes()
            workspace = Path(directory) / "workspace"
            prepare_workspace(root, workspace, None)
            (workspace / "content/preferences.md").write_text("changed\n", encoding="utf-8")
            backup = root / ".content.backup"

            publish_workspace(root, workspace, backup)
            self.assertEqual((root / "content/preferences.md").read_text(encoding="utf-8"), "changed\n")
            rollback_workspace(root, backup)

            self.assertEqual((root / "content/preferences.md").read_bytes(), original)
            self.assertFalse(backup.exists())

    def test_database_backup_restores_previous_materialization(self):
        with tempfile.TemporaryDirectory() as directory:
            database = Path(directory) / "verse.sqlite"
            backup = Path(directory) / "previous.sqlite"
            connection = sqlite3.connect(database)
            connection.execute("CREATE TABLE state (value INTEGER NOT NULL)")
            connection.execute("INSERT INTO state VALUES (1)")
            connection.commit()
            connection.close()

            backup_database(database, backup)
            connection = sqlite3.connect(database)
            connection.execute("UPDATE state SET value = 2")
            connection.commit()
            connection.close()
            restore_database(database, backup)

            connection = sqlite3.connect(database)
            self.assertEqual(connection.execute("SELECT value FROM state").fetchone()[0], 1)
            connection.close()


if __name__ == "__main__":
    unittest.main()
