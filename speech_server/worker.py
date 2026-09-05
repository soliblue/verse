import json
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path


class Worker:
    def __init__(self, config, store):
        self.config = config
        self.store = store
        self.stop = threading.Event()
        self.wake = threading.Event()
        self.thread = threading.Thread(target=self.run, daemon=True)

    def start(self):
        self.store.recover()
        self.thread.start()

    def close(self):
        self.stop.set()
        self.wake.set()
        self.thread.join(timeout=10)

    def run(self):
        while not self.stop.is_set():
            queued = [job for job in reversed(self.store.list()) if job["state"] == "queued"]
            if not queued:
                self.wake.wait(2)
                self.wake.clear()
                continue
            self.process(queued[0])

    def process(self, job):
        self.store.update(job["id"], state="transcribing")
        try:
            with tempfile.TemporaryDirectory(prefix="verse-speech-") as directory:
                output = Path(directory) / "result.json"
                command = [sys.executable, "-m", "speech_server.engine", str(self.config.audio / job["id"]), str(output), str(self.config.model_path(job["model"])), job["language"], str(self.config.maximum_duration), str(self.config.cpu_threads)]
                with subprocess.Popen(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) as process:
                    deadline = time.monotonic() + self.config.job_timeout
                    while process.poll() is None:
                        if self.stop.is_set() or self.store.get(job["id"]) is None:
                            process.terminate()
                            process.wait(timeout=5)
                            return
                        if time.monotonic() > deadline:
                            process.kill()
                            raise TimeoutError("Transcription exceeded the time limit")
                        self.stop.wait(0.5)
                    if process.returncode:
                        raise ValueError("Audio could not be transcribed. Check the file and try again.")
                self.store.update(job["id"], state="completed", **json.loads(output.read_text()))
        except Exception as error:
            self.store.update(job["id"], state="failed", error=str(error))
