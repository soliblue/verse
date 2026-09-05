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
        self.process_handle = None
        self.loaded_model = None
        self.last_used = 0
        self.warmup_model = None

    def start(self):
        self.store.recover()
        self.thread.start()

    def close(self):
        self.stop.set()
        self.wake.set()
        self.thread.join(timeout=10)
        self.release_model()

    def release_model(self):
        process = self.process_handle
        self.process_handle = None
        self.loaded_model = None
        if process is not None:
            if process.poll() is None:
                process.kill()
            process.wait()
            if process.stdin is not None:
                process.stdin.close()

    def warmup(self, model):
        if model in self.config.models:
            self.warmup_model = model
            self.wake.set()

    def ensure_model(self, name):
        if self.loaded_model != name or self.process_handle is None or self.process_handle.poll() is not None:
            self.release_model()
            command = [sys.executable, "-m", "speech_server.engine", str(self.config.model_path(name)), str(self.config.cpu_threads)]
            self.process_handle = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, text=True)
            self.loaded_model = name
        self.last_used = time.monotonic()

    def run(self):
        while not self.stop.is_set():
            queued = [job for job in reversed(self.store.list()) if job["state"] == "queued"]
            if not queued:
                if self.warmup_model is not None:
                    model = self.warmup_model
                    self.warmup_model = None
                    self.process(warmup_model=model)
                if self.process_handle is not None and time.monotonic() - self.last_used >= self.config.model_idle_timeout:
                    self.release_model()
                self.wake.wait(2)
                self.wake.clear()
                continue
            self.process(queued[0])

    def process(self, job=None, warmup_model=None):
        if job is not None:
            self.store.update(job["id"], state="transcribing")
        try:
            if warmup_model is not None:
                self.ensure_model(warmup_model)
                return
            with tempfile.TemporaryDirectory(prefix="verse-speech-") as directory:
                output = Path(directory) / "result.json"
                self.ensure_model(job["model"])
                process = self.process_handle
                process.stdin.write(json.dumps(dict(audio=str(self.config.audio / job["id"]), output=str(output), language=job["language"], maximum_duration=self.config.maximum_duration)) + "\n")
                process.stdin.flush()
                deadline = time.monotonic() + self.config.job_timeout
                while not output.is_file():
                    if self.stop.is_set() or self.store.get(job["id"]) is None:
                        self.release_model()
                        return
                    if time.monotonic() > deadline:
                        raise TimeoutError("Transcription exceeded the time limit")
                    if process.poll() is not None:
                        raise ValueError("Audio could not be transcribed. Check the file and try again.")
                    self.stop.wait(0.05)
                self.store.update(job["id"], state="completed", **json.loads(output.read_text()))
                self.last_used = time.monotonic()
        except Exception as error:
            self.release_model()
            if job is not None:
                self.store.update(job["id"], state="failed", error=str(error))
