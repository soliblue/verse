import hashlib
import os
import re
import shutil
import time


CHUNK_BYTES = 32 * 1024


class UploadError(ValueError):
    pass


class Uploads:
    def __init__(self, config):
        self.config = config
        self.root = config.audio / ".uploads"

    def clean(self):
        if self.root.exists():
            for directory in self.root.iterdir():
                if directory.is_dir() and time.time() - directory.stat().st_mtime > 3600:
                    shutil.rmtree(directory)

    def directory(self, identifier):
        if not re.fullmatch(r"[a-f0-9]{32}", identifier):
            raise UploadError("Invalid upload identifier")
        return self.root / identifier

    def put(self, identifier, index, data, reserved_bytes=0):
        self.clean()
        if not 0 <= index < (self.config.maximum_upload + CHUNK_BYTES - 1) // CHUNK_BYTES:
            raise UploadError("Invalid chunk index")
        if not 0 < len(data) <= CHUNK_BYTES:
            raise UploadError("Invalid chunk size")
        directory = self.directory(identifier)
        if not directory.exists() and self.root.exists() and len(list(self.root.iterdir())) >= 8:
            raise UploadError("Too many unfinished recordings")
        used = sum(path.stat().st_size for path in self.config.audio.rglob("*") if path.is_file())
        if used + reserved_bytes + len(data) > self.config.maximum_storage or shutil.disk_usage(self.config.audio).free < len(data) + 512 * 1024 * 1024:
            raise UploadError("Recording storage is full")
        directory.mkdir(parents=True, exist_ok=True, mode=0o700)
        self.root.chmod(0o700)
        temporary = directory / "pending"
        temporary.write_bytes(data)
        temporary.chmod(0o600)
        temporary.replace(directory / str(index))
        os.utime(directory, None)
        return hashlib.sha256(data).hexdigest()

    def assemble(self, identifier, manifest):
        directory = self.directory(identifier)
        size = manifest.get("size")
        hashes = manifest.get("chunks")
        digest = manifest.get("sha256")
        if type(size) is not int or not 0 < size <= self.config.maximum_upload:
            raise UploadError("Invalid recording size")
        if not isinstance(hashes, list) or len(hashes) != (size + CHUNK_BYTES - 1) // CHUNK_BYTES:
            raise UploadError("Invalid recording manifest")
        if not isinstance(digest, str) or not re.fullmatch(r"[a-f0-9]{64}", digest):
            raise UploadError("Invalid recording checksum")
        for index, expected in enumerate(hashes):
            path = directory / str(index)
            if not path.is_file() or not isinstance(expected, str):
                raise UploadError("Recording chunk missing")
            data = path.read_bytes()
            expected_size = min(CHUNK_BYTES, size - index * CHUNK_BYTES)
            if len(data) != expected_size or hashlib.sha256(data).hexdigest() != expected:
                raise UploadError("Recording chunk does not match")
        if shutil.disk_usage(self.config.audio).free < size * 2 + 512 * 1024 * 1024:
            raise UploadError("The server needs more free storage")
        output = directory / "audio"
        used = sum(path.stat().st_size for path in self.config.audio.rglob("*") if path.is_file() and path != output)
        if used + size > self.config.maximum_storage:
            raise UploadError("Recording storage is full")
        checksum = hashlib.sha256()
        with output.open("wb") as stream:
            output.chmod(0o600)
            for index in range(len(hashes)):
                data = (directory / str(index)).read_bytes()
                checksum.update(data)
                stream.write(data)
        if checksum.hexdigest() != digest:
            output.unlink()
            raise UploadError("Recording checksum does not match")
        return output

    def remove(self, identifier):
        directory = self.directory(identifier)
        if directory.exists():
            shutil.rmtree(directory)
