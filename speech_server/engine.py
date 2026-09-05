import argparse
import json
import subprocess
from pathlib import Path


FORMATS = "wav,mp3,mov,matroska,webm,ogg,flac,aac,amr,aiff,caf,asf"


def inspect_audio(path):
    result = subprocess.run(["ffprobe", "-v", "error", "-protocol_whitelist", "file,pipe", "-format_whitelist", FORMATS, "-select_streams", "a:0", "-show_entries", "stream=codec_type:format=duration", "-of", "json", str(path)], capture_output=True, timeout=20, check=True)
    value = json.loads(result.stdout)
    if not value.get("streams"):
        raise ValueError("File has no audio track")
    duration = value.get("format", {}).get("duration")
    return float(duration) if duration else None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("audio", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("model", type=Path)
    parser.add_argument("language")
    parser.add_argument("duration", type=int)
    parser.add_argument("threads", type=int)
    args = parser.parse_args()
    decoded = args.output.with_suffix(".wav")
    subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-xerror", "-protocol_whitelist", "file,pipe", "-format_whitelist", FORMATS, "-i", str(args.audio), "-map", "0:a:0", "-vn", "-t", str(args.duration + 1), "-ac", "1", "-ar", "16000", "-y", str(decoded)], check=True, timeout=120, capture_output=True)
    duration = inspect_audio(decoded)
    if not duration or duration > args.duration:
        raise ValueError("Audio must contain between 0 and 3600 seconds")
    from faster_whisper import WhisperModel
    model = WhisperModel(str(args.model), device="cpu", compute_type="int8", cpu_threads=args.threads, num_workers=1, local_files_only=True)
    segments, info = model.transcribe(str(decoded), language=None if args.language == "auto" else args.language, vad_filter=True, beam_size=5)
    rows = [dict(start=segment.start, end=segment.end, text=segment.text.strip()) for segment in segments]
    args.output.write_text(json.dumps(dict(text=" ".join(row["text"] for row in rows), segments=rows, detected_language=info.language, duration_seconds=duration)))


if __name__ == "__main__":
    main()
