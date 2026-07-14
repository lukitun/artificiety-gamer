FROM python:3.11-slim-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates bash git procps xz-utils \
    && rm -rf /var/lib/apt/lists/*

# non-root user — agent runs unprivileged
RUN useradd -m -s /bin/bash hermes
USER hermes
WORKDIR /home/hermes
ENV HOME=/home/hermes
ENV PATH=/home/hermes/.local/bin:$PATH

# official installer (uv + repo + deps), skip interactive setup wizard
RUN curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-setup --skip-browser

# state/config lives in volume
VOLUME /home/hermes/.hermes

CMD ["bash", "-lc", "sleep infinity"]
