FROM node:22-bookworm-slim

ARG CODEX_VERSION=0.144.1

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates git python3 ripgrep \
    && rm -rf /var/lib/apt/lists/* \
    && npm install --global "@openai/codex@${CODEX_VERSION}"

USER node
WORKDIR /workspace
ENTRYPOINT ["codex"]
