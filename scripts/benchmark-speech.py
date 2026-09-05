import argparse
import hashlib
import json
import time
from pathlib import Path

from faster_whisper import WhisperModel


parser = argparse.ArgumentParser()
parser.add_argument("audio", type=Path)
parser.add_argument("model", type=Path)
parser.add_argument("--threads", type=int, default=4)
parser.add_argument("--runs", type=int, default=3)
parser.add_argument("--language", default="en")
args = parser.parse_args()
started = time.monotonic()
model = WhisperModel(str(args.model), device="cpu", compute_type="int8", cpu_threads=args.threads, num_workers=1, local_files_only=True)
print(json.dumps(dict(model_load_seconds=round(time.monotonic() - started, 3), threads=args.threads)), flush=True)
for index in range(args.runs):
    started = time.monotonic()
    segments, info = model.transcribe(str(args.audio), language=None if args.language == "auto" else args.language, vad_filter=True, beam_size=5)
    text = " ".join(segment.text.strip() for segment in segments)
    print(json.dumps(dict(run=index + 1, seconds=round(time.monotonic() - started, 3), audio_seconds=info.duration, text_sha256=hashlib.sha256(text.encode()).hexdigest(), characters=len(text))), flush=True)
