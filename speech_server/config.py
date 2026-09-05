import os
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Config:
    secret: str
    database: Path = Path("db/transcriptions.sqlite")
    audio: Path = Path("db/recordings")
    models_dir: Path = Path("models")
    models: tuple[str, ...] = ("small", "medium")
    default_model: str = "medium"
    maximum_upload: int = 50 * 1024 * 1024
    maximum_duration: int = 3600
    job_timeout: int = 7200
    cpu_threads: int = 4
    maximum_storage: int = 5 * 1024 * 1024 * 1024
    model_idle_timeout: int = 300

    @classmethod
    def environment(cls):
        secret = os.environ.get("VERSE_DEVICE_SECRET", "")
        if len(secret) < 24:
            raise ValueError("VERSE_DEVICE_SECRET must contain at least 24 characters")
        config = cls(
            secret=secret,
            database=Path(os.environ.get("VERSE_SPEECH_DB", "db/transcriptions.sqlite")),
            audio=Path(os.environ.get("VERSE_AUDIO_DIR", "db/recordings")),
            models_dir=Path(os.environ.get("VERSE_WHISPER_MODELS", "models")),
            models=tuple(os.environ.get("VERSE_WHISPER_MODELS_ALLOWED", "small,medium").split(",")),
            default_model=os.environ.get("VERSE_WHISPER_DEFAULT_MODEL", "medium"),
            job_timeout=int(os.environ.get("VERSE_WHISPER_TIMEOUT", "7200")),
            cpu_threads=int(os.environ.get("VERSE_WHISPER_THREADS", "4")),
            maximum_storage=int(os.environ.get("VERSE_AUDIO_STORAGE_BYTES", str(5 * 1024 * 1024 * 1024))),
            model_idle_timeout=int(os.environ.get("VERSE_WHISPER_IDLE_TIMEOUT", "300")),
        )
        if config.default_model not in config.models:
            raise ValueError("Default model must be allowed")
        for model in config.models:
            config.model_path(model)
        return config

    def model_path(self, name):
        if name not in ("small", "medium", "large-v3"):
            raise ValueError("Unsupported model")
        direct = self.models_dir / name
        if (direct / "model.bin").is_file():
            return direct
        snapshots = self.models_dir / f"models--Systran--faster-whisper-{name}" / "snapshots"
        matches = sorted(snapshots.glob("*/model.bin"))
        if not matches:
            raise ValueError(f"Download the {name} model before enabling it")
        return matches[-1].parent
