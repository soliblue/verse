import os
import shutil
import sqlite3
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from scripts.codex_app_thread import (
    agent_environment,
    completed_after_idle,
    sandbox_policy,
    should_wait_for_retry,
)
from scripts.nightjar_workspace import (
    backup_database,
    prepare_workspace,
    publish_workspace,
    restore_database,
    rollback_workspace,
    stamp_agent_provenance,
    validate_workspace,
)
from etl.content import parse_document, render_document


ROOT = Path(__file__).resolve().parents[1]


class NightjarAgentTests(unittest.TestCase):
    def set_story_kind(self, path: Path, kind: str) -> None:
        metadata, body = parse_document(path)
        metadata["kind"] = kind
        path.write_text(render_document(metadata, body), encoding="utf-8")

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
        self.assertTrue(should_wait_for_retry({"willRetry": True}))
        self.assertFalse(should_wait_for_retry({"willRetry": False}))
        self.assertTrue(
            completed_after_idle(
                "thread/status/changed",
                {"threadId": "thread", "status": {"type": "idle"}},
                "thread",
                True,
            )
        )
        self.assertFalse(
            completed_after_idle(
                "thread/status/changed",
                {"threadId": "thread", "status": {"type": "idle"}},
                "thread",
                False,
            )
        )

    def test_agent_model_identity_is_stamped_from_protocol(self):
        with tempfile.TemporaryDirectory() as directory:
            workspace = Path(directory) / "workspace"
            shutil.copytree(ROOT / "content", workspace / "content")
            agent_result = Path(directory) / "agent-result.json"
            agent_result.write_text('{"status":"completed"}\n', encoding="utf-8")
            protocol_log = Path(directory) / "protocol.jsonl"
            protocol_log.write_text(
                '{"payload":{"result":{"model":"gpt-5.6-sol","modelProvider":"openai"}}}\n',
                encoding="utf-8",
            )

            result = stamp_agent_provenance(
                workspace,
                "2026-07-12",
                agent_result,
                protocol_log,
            )
            metadata, _ = parse_document(
                workspace / "content/editions/2026-07-12/01-meta-physics-video-world-models-2026.md"
            )

            self.assertEqual(result["model"], "gpt-5.6-sol")
            self.assertEqual(metadata["model_name"], "gpt-5.6-sol")
            self.assertEqual(metadata["model_provider"], "openai")

    def test_staged_first_edition_validates_and_materializes_explore(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "verse"
            root.mkdir()
            shutil.copytree(ROOT / "content", root / "content")
            workspace = Path(directory) / "workspace"
            prepare_workspace(root, workspace, None)
            event_paths = []
            for path in sorted((workspace / "content/editions/2026-07-12").glob("*.md")):
                metadata, _ = parse_document(path)
                if metadata.get("kind") == "event":
                    event_paths.append(path)
            for path in event_paths[2:]:
                self.set_story_kind(path, "technique")

            result = validate_workspace(root, workspace, "2026-07-12")

            self.assertEqual(result["stories"], 10)
            self.assertGreater(result["citations"], 10)
            self.assertTrue((workspace / "content/explore/current.json").is_file())

    def test_agent_edition_does_not_require_covers(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "verse"
            root.mkdir()
            shutil.copytree(ROOT / "content", root / "content")
            workspace = Path(directory) / "workspace"
            prepare_workspace(root, workspace, None)
            edition = workspace / "content/editions/2026-07-12"
            shutil.rmtree(edition / "assets")
            for path in edition.glob("[0-9][0-9]-*.md"):
                metadata, body = parse_document(path)
                metadata = {key: value for key, value in metadata.items() if not key.startswith("cover")}
                path.write_text(render_document(metadata, body), encoding="utf-8")
            event_paths = []
            for path in sorted(edition.glob("[0-9][0-9]-*.md")):
                metadata, _ = parse_document(path)
                if metadata.get("kind") == "event":
                    event_paths.append(path)
            for path in event_paths[2:]:
                self.set_story_kind(path, "technique")

            result = validate_workspace(root, workspace, "2026-07-12")

            self.assertEqual(result["stories"], 10)
            self.assertFalse((edition / "assets").exists())

    def test_agent_edition_rejects_more_than_two_event_stories(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "verse"
            root.mkdir()
            shutil.copytree(ROOT / "content", root / "content")
            workspace = Path(directory) / "workspace"
            prepare_workspace(root, workspace, None)
            story_paths = sorted((workspace / "content/editions/2026-07-12").glob("[0-9][0-9]-*.md"))
            for path in story_paths[:3]:
                self.set_story_kind(path, "event")

            with self.assertRaisesRegex(ValueError, "at most two event stories"):
                validate_workspace(root, workspace, "2026-07-12")

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
