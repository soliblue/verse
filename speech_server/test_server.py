import io
import json
import subprocess
import sys
import tempfile
import threading
import unittest
import wave
from dataclasses import replace
from http.client import HTTPConnection
from pathlib import Path
from unittest.mock import patch

from speech_server.config import Config
from speech_server.http import Server
from speech_server.store import Store


class SpeechTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        root = Path(self.directory.name)
        self.config = Config("x" * 32, root / "test.sqlite", root / "audio")
        self.server = Server(("127.0.0.1", 0), self.config)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()
        self.directory.cleanup()

    def request(self, method, path, data=None, authenticated=True):
        connection = HTTPConnection(*self.server.server_address)
        headers = {"Authorization": "Bearer " + self.config.secret} if authenticated else {}
        connection.request(method, path, body=data, headers=headers)
        response = connection.getresponse()
        raw = response.read()
        connection.close()
        return response.status, json.loads(raw) if raw else None

    def audio(self):
        output = io.BytesIO()
        with wave.open(output, "wb") as stream:
            stream.setnchannels(1)
            stream.setsampwidth(2)
            stream.setframerate(16000)
            stream.writeframes(b"\0\0" * 16000)
        return output.getvalue()

    def test_auth_and_health(self):
        self.assertEqual(self.request("GET", "/health", authenticated=False)[0], 200)
        self.assertEqual(self.request("GET", "/v1/transcriptions", authenticated=False)[0], 401)
        self.assertEqual(self.request("POST", "/v1/transcriptions", b"audio", False)[0], 401)
        self.assertEqual(self.request("GET", "/v1/config")[1]["default_model"], "medium")

    def test_invalid_audio_and_parameters(self):
        self.assertEqual(self.request("POST", "/v1/transcriptions", b"not audio")[0], 400)
        self.assertEqual(self.request("POST", "/v1/transcriptions?model=unknown", self.audio())[0], 400)
        self.assertEqual(self.request("POST", "/v1/transcriptions?origin=invalid", self.audio())[0], 400)
        self.assertEqual(self.server.store.list(), [])
        self.assertEqual(list(self.config.audio.iterdir()), [])

    def test_upload_list_get_delete(self):
        status, job = self.request("POST", "/v1/transcriptions?filename=Test.wav&language=en", self.audio())
        self.assertEqual(status, 202)
        self.assertEqual(job["state"], "queued")
        self.assertEqual(job["origin"], "unknown")
        self.assertAlmostEqual(job["duration_seconds"], 1)
        path = "/v1/transcriptions/" + job["id"]
        self.assertEqual(self.request("GET", path)[1], job)
        self.assertEqual(len(self.request("GET", "/v1/transcriptions")[1]["transcriptions"]), 1)
        self.assertEqual(self.request("DELETE", path)[0], 204)
        self.assertEqual(self.request("GET", path)[0], 404)
        self.assertEqual(list(self.config.audio.iterdir()), [])

    def test_upload_origin_survives_completion_and_store_reopen(self):
        for origin in ["app", "shared", "keyboard", "unknown"]:
            status, job = self.request("POST", "/v1/transcriptions?origin=" + origin, self.audio())
            self.assertEqual(status, 202)
            self.assertEqual(job["origin"], origin)
            self.server.store.update(job["id"], state="completed", text="Hello, see you at eight.")
            restored = Store(self.config.database).get(job["id"])
            self.assertEqual(restored["origin"], origin)
            self.assertEqual(restored["text"], "Hello, see you at eight.")
            fetched = self.request("GET", "/v1/transcriptions/" + job["id"])[1]
            self.assertEqual(fetched["origin"], origin)

    def test_restart_recovers_interrupted_jobs_and_preserves_completed(self):
        first = self.server.store.create("a.wav", "medium", "auto", 1)
        second = self.server.store.create("b.wav", "medium", "auto", 1)
        self.server.store.update(first["id"], state="transcribing")
        self.server.store.update(second["id"], state="completed", text="hello")
        self.server.store.recover()
        self.assertEqual(self.server.store.get(first["id"])["state"], "queued")
        self.assertEqual(self.server.store.get(second["id"])["text"], "hello")

    def test_failed_worker_is_recorded_and_deleted_job_stays_deleted(self):
        job = self.server.store.create("a.wav", "medium", "auto", 1)
        self.server.worker.process(job)
        self.assertEqual(self.server.store.get(job["id"])["state"], "failed")
        self.server.store.delete(job["id"])
        self.server.store.update(job["id"], state="completed", text="hello")
        self.assertIsNone(self.server.store.get(job["id"]))

    def test_overlong_audio_rejected(self):
        with patch("speech_server.http.inspect_audio", return_value=3601):
            self.assertEqual(self.request("POST", "/v1/transcriptions", self.audio())[0], 400)
        self.assertEqual(list(self.config.audio.iterdir()), [])

    def test_playlist_is_rejected(self):
        playlist = b"#EXTM3U\n#EXTINF:1,secret\nfile:///etc/passwd\n"
        self.assertEqual(self.request("POST", "/v1/transcriptions", playlist)[0], 400)

    def test_storage_and_queue_limits(self):
        self.server.config = replace(self.config, maximum_storage=10)
        self.assertEqual(self.request("POST", "/v1/transcriptions", self.audio())[0], 507)
        self.server.config = self.config
        for index in range(20):
            self.server.store.create(f"{index}.wav", "small", "auto", 1)
        self.assertEqual(self.request("POST", "/v1/transcriptions", self.audio())[0], 429)
        self.assertEqual(list(self.config.audio.iterdir()), [])

    def test_path_traversal_is_not_an_audio_identifier(self):
        self.assertEqual(self.request("GET", "/v1/transcriptions/../../etc/passwd/audio")[0], 404)
        self.assertEqual(self.request("GET", "/v1/transcriptions/%2e%2e/audio")[0], 404)

    def test_worker_timeout_terminates_subprocess(self):
        job = self.server.store.create("a.wav", "medium", "auto", 1)
        process = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(60)"], stdin=subprocess.PIPE, text=True)
        with patch("speech_server.config.Config.model_path", return_value=Path("model")), patch("speech_server.worker.subprocess.Popen", return_value=process), patch("speech_server.worker.time.monotonic", side_effect=[0, 0, 10000]):
            self.server.worker.process(job)
        self.assertIsNotNone(process.poll())
        result = self.server.store.get(job["id"])
        self.assertEqual(result["state"], "failed")
        self.assertIn("time limit", result["error"])

    def test_recording_requires_auth_and_returns_exact_bytes(self):
        audio = self.audio()
        _, job = self.request("POST", "/v1/transcriptions", audio)
        path = "/v1/transcriptions/" + job["id"] + "/audio"
        self.assertEqual(self.request("GET", path, authenticated=False)[0], 401)
        connection = HTTPConnection(*self.server.server_address)
        connection.request("GET", path, headers={"Authorization": "Bearer " + self.config.secret})
        response = connection.getresponse()
        self.assertEqual(response.status, 200)
        self.assertEqual(response.read(), audio)
        connection.close()


if __name__ == "__main__":
    unittest.main()
