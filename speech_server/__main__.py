import os
import signal
import threading

from speech_server.environment import load_environment
from speech_server.config import Config
from speech_server.http import Server


def main():
    os.umask(0o077)
    load_environment()
    server = Server((os.environ.get("VERSE_HOST", "127.0.0.1"), int(os.environ.get("VERSE_PORT", "8787"))), Config.environment())
    server.worker.start()
    def stop(signum, frame):
        threading.Thread(target=server.shutdown, daemon=True).start()
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    try:
        server.serve_forever()
    finally:
        server.worker.close()
        server.server_close()


if __name__ == "__main__":
    main()
