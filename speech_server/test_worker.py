import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from speech_server.config import Config
from speech_server.store import Store
from speech_server.worker import Worker


ENGINE = """
import json
import sys
from pathlib import Path
for line in sys.stdin:
    request = json.loads(line)
    output = Path(request['output'])
    pending = output.with_suffix('.pending')
    pending.write_text(json.dumps(dict(text='hello', segments=[], duration_seconds=1)))
    pending.replace(output)
"""


class WorkerTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        root = Path(self.directory.name)
        self.config = Config("x" * 32, root / "test.sqlite", root / "audio")
        self.store = Store(self.config.database)
        self.worker = Worker(self.config, self.store)
        self.popen = subprocess.Popen

    def tearDown(self):
        self.worker.release_model()
        self.directory.cleanup()

    def engine(self, command, **kwargs):
        return self.popen([sys.executable, "-c", ENGINE], **kwargs)

    def test_reuses_model_process_for_consecutive_jobs(self):
        with patch.object(Config, "model_path", return_value=Path("model")), patch("speech_server.worker.subprocess.Popen", side_effect=self.engine) as start:
            first = self.store.create("a.wav", "medium", "en", 1)
            second = self.store.create("b.wav", "medium", "en", 1)
            self.worker.process(first)
            process = self.worker.process_handle
            self.worker.process(second)
            self.assertEqual(start.call_count, 1)
            self.assertIs(self.worker.process_handle, process)
            self.assertIsNone(process.poll())
            self.assertEqual(self.store.get(first["id"])["text"], "hello")
            self.assertEqual(self.store.get(second["id"])["state"], "completed")

    def test_model_switch_releases_previous_process(self):
        with patch.object(Config, "model_path", return_value=Path("model")), patch("speech_server.worker.subprocess.Popen", side_effect=self.engine) as start:
            self.worker.process(self.store.create("a.wav", "medium", "en", 1))
            first = self.worker.process_handle
            self.worker.process(self.store.create("b.wav", "small", "en", 1))
            self.assertEqual(start.call_count, 2)
            self.assertIsNotNone(first.poll())
            self.assertIsNone(self.worker.process_handle.poll())

    def test_dead_process_is_replaced(self):
        with patch.object(Config, "model_path", return_value=Path("model")), patch("speech_server.worker.subprocess.Popen", side_effect=self.engine) as start:
            self.worker.process(self.store.create("a.wav", "medium", "en", 1))
            self.worker.process_handle.kill()
            self.worker.process_handle.wait()
            job = self.store.create("b.wav", "medium", "en", 1)
            self.worker.process(job)
            self.assertEqual(start.call_count, 2)
            self.assertEqual(self.store.get(job["id"])["state"], "completed")

    def test_cancel_releases_process(self):
        with patch.object(Config, "model_path", return_value=Path("model")), patch("speech_server.worker.subprocess.Popen", side_effect=self.engine):
            self.worker.stop.set()
            self.worker.process(self.store.create("a.wav", "medium", "en", 1))
            self.assertIsNone(self.worker.process_handle)


if __name__ == "__main__":
    unittest.main()
