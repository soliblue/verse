import os

from db.connection import database
from db.environment import load_environment
from db.migrations import migrate
from server.app import ServerConfig, create_server


def main() -> int:
    os.umask(0o077)
    load_environment()
    config = ServerConfig.environment()
    if os.environ.get("MORROW_AUTO_MIGRATE", "1") == "1":
        with database(config.database_path) as connection:
            migrate(connection)
    host = os.environ.get("MORROW_HOST", "127.0.0.1")
    port = int(os.environ.get("MORROW_PORT", "8787"))
    server = create_server(config, host, port)
    print(f"morrow server listening on http://{host}:{server.server_port}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
