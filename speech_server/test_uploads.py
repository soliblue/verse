import hashlib
import json
import os
import tempfile
import time
import unittest
from dataclasses import replace
from pathlib import Path

from speech_server.config import Config
from speech_server import test_server
from speech_server.uploads import CHUNK_BYTES, UploadError, Uploads


class StagedUploadTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.config = Config("x" * 32, audio=Path(self.temporary.name))
        self.uploads = Uploads(self.config)
        self.identifier = "a" * 32

    def tearDown(self):
        self.temporary.cleanup()

    def manifest(self, data):
        chunks = [data[offset:offset + CHUNK_BYTES] for offset in range(0, len(data), CHUNK_BYTES)]
        return {"size": len(data), "chunks": [hashlib.sha256(chunk).hexdigest() for chunk in chunks], "sha256": hashlib.sha256(data).hexdigest()}

    def test_header_rewrite_and_order_preserve_every_byte(self):
        data = b"a" * CHUNK_BYTES + b"b" * CHUNK_BYTES + b"tail"
        self.uploads.put(self.identifier, 1, data[CHUNK_BYTES:2 * CHUNK_BYTES])
        self.uploads.put(self.identifier, 0, b"old header" + data[10:CHUNK_BYTES])
        self.uploads.put(self.identifier, 2, b"tail")
        with self.assertRaises(UploadError):
            self.uploads.assemble(self.identifier, self.manifest(data))
        self.uploads.put(self.identifier, 0, data[:CHUNK_BYTES])
        self.uploads.put(self.identifier, 0, data[:CHUNK_BYTES])
        path = self.uploads.assemble(self.identifier, self.manifest(data))
        self.assertEqual(path.read_bytes(), data)
        self.assertEqual(path.stat().st_mode & 0o777, 0o600)

    def test_missing_chunk_and_full_checksum_rejected(self):
        with self.assertRaises(UploadError):
            self.uploads.assemble(self.identifier, self.manifest(b"abc"))
        self.uploads.put(self.identifier, 0, b"abc")
        manifest = self.manifest(b"abc")
        manifest["sha256"] = "0" * 64
        with self.assertRaises(UploadError):
            self.uploads.assemble(self.identifier, manifest)

    def test_bounds_and_expiration(self):
        for identifier, index, data in [("../escape", 0, b"a"), (self.identifier, -1, b"a"), (self.identifier, 0, b""), (self.identifier, 0, b"a" * (CHUNK_BYTES + 1))]:
            with self.assertRaises(UploadError):
                self.uploads.put(identifier, index, data)
        self.uploads.put(self.identifier, 0, b"abc")
        directory = self.uploads.directory(self.identifier)
        os.utime(directory, (time.time() - 3601, time.time() - 3601))
        self.uploads.clean()
        self.assertFalse(directory.exists())
        self.uploads.config = replace(self.config, maximum_storage=1)
        with self.assertRaises(UploadError):
            self.uploads.put(self.identifier, 0, b"abc")


class StagedHTTPTests(unittest.TestCase):
    setUp = test_server.SpeechTests.setUp
    tearDown = test_server.SpeechTests.tearDown
    request = test_server.SpeechTests.request
    audio = test_server.SpeechTests.audio

    def test_staged_recording_is_authenticated_and_finalization_idempotent(self):
        identifier = "b" * 32
        data = self.audio()
        path = "/v1/uploads/" + identifier
        self.assertEqual(self.request("POST", path + "/0", data, False)[0], 401)
        chunks = [data[offset:offset + CHUNK_BYTES] for offset in range(0, len(data), CHUNK_BYTES)]
        for index, chunk in enumerate(chunks):
            self.assertEqual(self.request("POST", path + "/" + str(index), chunk)[0], 200)
        manifest = json.dumps({"size": len(data), "chunks": [hashlib.sha256(chunk).hexdigest() for chunk in chunks], "sha256": hashlib.sha256(data).hexdigest()}).encode()
        status, job = self.request("POST", path + "/finish?model=medium&filename=recording.wav", manifest)
        self.assertEqual(status, 202)
        self.assertEqual(job["id"], identifier)
        self.assertEqual((self.config.audio / identifier).read_bytes(), data)
        self.assertEqual(self.request("POST", path + "/finish", manifest)[1]["id"], identifier)
        self.assertEqual(self.request("POST", "/v1/transcriptions?upload_id=" + identifier, data)[1]["id"], identifier)
        self.assertEqual(len(self.server.store.list()), 1)
        self.assertFalse(self.server.uploads.directory(identifier).exists())

    def test_invalid_manifest_and_audio_do_not_create_job(self):
        path = "/v1/uploads/" + "c" * 32
        self.assertEqual(self.request("POST", path + "/finish", b"{")[0], 400)
        data = b"not audio"
        self.assertEqual(self.request("POST", path + "/0", data)[0], 200)
        digest = hashlib.sha256(data).hexdigest()
        manifest = json.dumps({"size": len(data), "chunks": [digest], "sha256": digest}).encode()
        self.assertEqual(self.request("POST", path + "/finish", manifest)[0], 400)
        self.assertEqual(self.server.store.list(), [])
        self.assertEqual(self.request("DELETE", path)[0], 204)
