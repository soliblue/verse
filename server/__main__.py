import os

from db.connection import database
from db.content import sync_content
from db.environment import load_environment
from db.explore import event_ranking_profile, publish_explore
from db.migrations import migrate
from etl.explore import build_explore, write_explore
from server.app import ServerConfig, create_server


def main() -> int:
    os.umask(0o077)
    load_environment()
    config = ServerConfig.environment()
    if os.environ.get("VERSE_AUTO_MIGRATE", "1") == "1":
        with database(config.database_path) as connection:
            migrate(connection)
            if config.content_path.is_dir():
                sync_content(connection, config.content_path, config.public_base_url)
                if (config.content_path / "places.md").is_file():
                    explore, source_events = build_explore(
                        config.content_path,
                        ranking_profile=event_ranking_profile(connection),
                    )
                    write_explore(config.content_path, explore)
                    publish_explore(connection, explore, source_events)
    host = os.environ.get("VERSE_HOST", "127.0.0.1")
    port = int(os.environ.get("VERSE_PORT", "8787"))
    server = create_server(config, host, port)
    print(f"verse server listening on http://{host}:{server.server_port}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
