import io
import json
import os
import tempfile
import unittest
import urllib.error
from pathlib import Path
from unittest.mock import patch

from speech_server.config import Config
from speech_server.engine import transcribe_cloudflare


class Response(io.BytesIO):
    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.close()


class CloudflareTests(unittest.TestCase):
    def test_cloudflare_environment_does_not_require_local_models(self):
        values = {
            "VERSE_DEVICE_SECRET": "x" * 32,
            "VERSE_SPEECH_ENGINE": "cloudflare",
            "CLOUDFLARE_ACCOUNT_ID": "a" * 32,
            "CLOUDFLARE_WORKERS_API_TOKEN": "secret",
        }
        with patch.dict(os.environ, values, clear=True):
            config = Config.environment()
        self.assertEqual(config.engine, "cloudflare")

    def test_cloudflare_result_keeps_server_contract(self):
        payload = {
            "success": True,
            "result": {
                "text": " Hello world. ",
                "segments": [{"start": 0.1, "end": 1.2, "text": " Hello world. ", "words": []}],
                "transcription_info": {"language": "en"},
            },
        }
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            audio = root / "audio.m4a"
            output = root / "result.json"
            audio.write_bytes(b"audio")
            environment = {
                "CLOUDFLARE_ACCOUNT_ID": "a" * 32,
                "CLOUDFLARE_WORKERS_API_TOKEN": "secret",
                "VERSE_CLOUDFLARE_MODEL": "@cf/openai/whisper-large-v3-turbo",
            }
            with patch.dict(os.environ, environment, clear=True), patch("speech_server.engine.inspect_audio", return_value=1.5), patch("speech_server.engine.urllib.request.urlopen", return_value=Response(json.dumps(payload).encode())) as open_request:
                transcribe_cloudflare(audio, output, "auto", 3600)
            result = json.loads(output.read_text())
            request = open_request.call_args.args[0]
        self.assertEqual(result["text"], "Hello world.")
        self.assertEqual(result["segments"], [{"start": 0.1, "end": 1.2, "text": "Hello world."}])
        self.assertEqual(result["detected_language"], "en")
        self.assertEqual(result["duration_seconds"], 1.5)
        self.assertEqual(request.headers["Authorization"], "Bearer secret")
        self.assertNotIn("secret", request.full_url)
        self.assertEqual(json.loads(request.data)["language"], None)

    def test_cloudflare_error_is_sanitized(self):
        error = urllib.error.HTTPError("https://example.invalid", 429, "", {}, io.BytesIO(json.dumps({"errors": [{"message": "Rate limit exceeded"}]}).encode()))
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            audio = root / "audio.m4a"
            audio.write_bytes(b"audio")
            environment = {"CLOUDFLARE_ACCOUNT_ID": "a" * 32, "CLOUDFLARE_WORKERS_API_TOKEN": "secret"}
            with patch.dict(os.environ, environment, clear=True), patch("speech_server.engine.inspect_audio", return_value=1), patch("speech_server.engine.urllib.request.urlopen", side_effect=error):
                with self.assertRaisesRegex(ValueError, "Cloudflare transcription failed: Rate limit exceeded"):
                    transcribe_cloudflare(audio, root / "result.json", "en", 3600)


if __name__ == "__main__":
    unittest.main()
