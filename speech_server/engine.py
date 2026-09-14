import argparse
import base64
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path


FORMATS = "wav,mp3,mov,matroska,webm,ogg,flac,aac,amr,aiff,caf,asf"


def inspect_audio(path):
    result = subprocess.run(["ffprobe", "-v", "error", "-protocol_whitelist", "file,pipe", "-format_whitelist", FORMATS, "-select_streams", "a:0", "-show_entries", "stream=codec_type:format=duration", "-of", "json", str(path)], capture_output=True, timeout=20, check=True)
    value = json.loads(result.stdout)
    if not value.get("streams"):
        raise ValueError("File has no audio track")
    duration = value.get("format", {}).get("duration")
    return float(duration) if duration else None


def transcribe(model, audio, output, language, maximum_duration):
    started = time.monotonic()
    decoded = output.with_suffix(".wav")
    subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-xerror", "-protocol_whitelist", "file,pipe", "-format_whitelist", FORMATS, "-i", str(audio), "-map", "0:a:0", "-vn", "-t", str(maximum_duration + 1), "-ac", "1", "-ar", "16000", "-y", str(decoded)], check=True, timeout=120, capture_output=True)
    duration = inspect_audio(decoded)
    if not duration or duration > maximum_duration:
        raise ValueError("Audio must contain between 0 and 3600 seconds")
    segments, info = model.transcribe(str(decoded), language=None if language == "auto" else language, vad_filter=True, beam_size=5)
    rows = [dict(start=segment.start, end=segment.end, text=segment.text.strip()) for segment in segments]
    temporary = output.with_suffix(".pending")
    temporary.write_text(json.dumps(dict(text=" ".join(row["text"] for row in rows), segments=rows, detected_language=info.language, duration_seconds=duration, inference_seconds=round(time.monotonic() - started, 3))))
    temporary.replace(output)


def transcribe_cloudflare(audio, output, language, maximum_duration):
    started = time.monotonic()
    duration = inspect_audio(audio)
    if not duration or duration > maximum_duration:
        raise ValueError("Audio must contain between 0 and 3600 seconds")
    account = os.environ["CLOUDFLARE_ACCOUNT_ID"]
    token = os.environ["CLOUDFLARE_WORKERS_API_TOKEN"]
    model = os.environ.get("VERSE_CLOUDFLARE_MODEL", "@cf/openai/whisper-large-v3-turbo")
    request = urllib.request.Request(
        f"https://api.cloudflare.com/client/v4/accounts/{account}/ai/run/{model}",
        data=json.dumps(dict(
            audio=base64.b64encode(audio.read_bytes()).decode(),
            task="transcribe",
            language=None if language == "auto" else language,
            vad_filter=True,
            beam_size=5,
        )).encode(),
        headers={"Authorization": "Bearer " + token, "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(request, timeout=int(os.environ.get("VERSE_WHISPER_TIMEOUT", "7200"))) as response:
            payload = json.load(response)
    except urllib.error.HTTPError as error:
        try:
            messages = [item.get("message", "") for item in json.load(error).get("errors", [])]
        except (json.JSONDecodeError, AttributeError):
            messages = []
        detail = next((message for message in messages if message), f"HTTP {error.code}")
        raise ValueError("Cloudflare transcription failed: " + detail) from None
    if not payload.get("success") or not isinstance(payload.get("result"), dict):
        raise ValueError("Cloudflare transcription returned an invalid response")
    result = payload["result"]
    rows = [dict(start=row["start"], end=row["end"], text=row.get("text", "").strip()) for row in result.get("segments", [])]
    info = result.get("transcription_info", {})
    text = result.get("text", "").strip()
    temporary = output.with_suffix(".pending")
    temporary.write_text(json.dumps(dict(
        text=text,
        segments=rows,
        detected_language=info.get("language", language if language != "auto" else None),
        duration_seconds=duration,
        inference_seconds=round(time.monotonic() - started, 3),
    )))
    temporary.replace(output)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("model", type=Path)
    parser.add_argument("threads", type=int)
    args = parser.parse_args()
    engine = os.environ.get("VERSE_SPEECH_ENGINE", "local")
    if engine == "local":
        from faster_whisper import WhisperModel
        model = WhisperModel(str(args.model), device="cpu", compute_type="int8", cpu_threads=args.threads, num_workers=1, local_files_only=True)
    for line in sys.stdin:
        request = json.loads(line)
        if engine == "cloudflare":
            transcribe_cloudflare(Path(request["audio"]), Path(request["output"]), request["language"], request["maximum_duration"])
        else:
            transcribe(model, Path(request["audio"]), Path(request["output"]), request["language"], request["maximum_duration"])


if __name__ == "__main__":
    main()
