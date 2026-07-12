import os
import re
from pathlib import Path


DEFAULT_ENVIRONMENT_FILE = Path(__file__).resolve().parents[1] / "server" / ".env"
ENVIRONMENT_KEY = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


def load_environment(path: Path = DEFAULT_ENVIRONMENT_FILE) -> None:
    if not path.exists():
        return
    for number, raw_line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line.removeprefix("export ").strip()
        key, separator, value = line.partition("=")
        if not separator or not ENVIRONMENT_KEY.fullmatch(key.strip()):
            raise ValueError(f"invalid environment entry at {path}:{number}")
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
            value = value[1:-1]
        os.environ.setdefault(key.strip(), value)
