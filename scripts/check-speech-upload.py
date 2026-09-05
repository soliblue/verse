import argparse
import hashlib
import json
import os
import time
from pathlib import Path
from urllib.request import Request, urlopen
from uuid import uuid4

from speech_server.environment import load_environment


parser = argparse.ArgumentParser()
parser.add_argument("audio", type=Path)
parser.add_argument("--base", default="http://127.0.0.1:8787")
args = parser.parse_args()
load_environment()
identifier = uuid4().hex


def request(method, path, data=None):
    headers = {"Authorization": "Bearer " + os.environ["VERSE_DEVICE_SECRET"], "Content-Type": "application/octet-stream", "User-Agent": "Verse-Smoke/0.3"}
    with urlopen(Request(args.base + path, data=data, method=method, headers=headers), timeout=60) as response:
        payload = response.read()
        return json.loads(payload) if payload else None


audio = args.audio.read_bytes()
chunks = [audio[offset:offset + 32768] for offset in range(0, len(audio), 32768)]
for index, chunk in enumerate(chunks):
    response = request("POST", f"/v1/uploads/{identifier}/{index}?model=medium", chunk)
    assert response["sha256"] == hashlib.sha256(chunk).hexdigest()
manifest = json.dumps(dict(size=len(audio), chunks=[hashlib.sha256(chunk).hexdigest() for chunk in chunks], sha256=hashlib.sha256(audio).hexdigest())).encode()
started = time.monotonic()
job = request("POST", f"/v1/uploads/{identifier}/finish?model=medium&language=en&filename=Smoke.wav", manifest)
assert job["id"] == identifier
assert request("POST", f"/v1/uploads/{identifier}/finish", manifest)["id"] == identifier
deadline = time.monotonic() + 180
while job["state"] in ("queued", "transcribing") and time.monotonic() < deadline:
    time.sleep(0.5)
    job = request("GET", f"/v1/transcriptions/{identifier}")
request("DELETE", f"/v1/transcriptions/{identifier}")
assert job["state"] == "completed", job["state"]
print(json.dumps(dict(state=job["state"], model=job["model"], seconds_after_finalize=round(time.monotonic() - started, 3), audio_bytes=len(audio), characters=len(job["text"]), deleted=True)))
