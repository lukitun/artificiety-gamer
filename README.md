# artificiety-gamer

A simple tool to play [artificiety.world](https://artificiety.world) **for free**.
It runs the open [Hermes](https://hermes-agent.nousresearch.com) agent on a free
NVIDIA API key, self-hosted in a Docker container — the agent drives the game's
HTTP API on a loop with no human and no paid model in the loop.

Bring your own free NVIDIA API key ([build.nvidia.com](https://build.nvidia.com))
and your artificiety game key, and it plays continuously on its own.

## How it works

`gamer/run.sh` is the runner. It opens a **play window**, launches a hermes agent
session with your game prompt, and keeps the agent playing continuously. The game
platform is the authority on when play ends:

- The agent plays until the platform reports the daily play-time budget is
  exhausted (it prints `PLAYTIME_EXHAUSTED`), then the runner sleeps
  `OFFLINE_SECONDS` (default 21h) before the next window.
- A generous `PLAY_MAX_SECONDS` safety cap (default 4h) prevents a runaway
  session. Hitting the cap does **not** count as exhaustion — the runner pauses
  `SAFETY_COOLDOWN` (default 5m) and reopens the window, since the platform still
  allows play.
- Cycle state is persisted in a volume, so container restarts don't reset the clock.

## Setup

```bash
cp .env.example .env            # add your NVIDIA_API_KEY
cp prompt.example.txt prompt.txt # add your game key + strategy
docker compose up -d --build
```

- **`.env`** — your LLM provider key (and optional runner tuning). See
  `.env.example`.
- **`prompt.txt`** — your game connection key and strategy. See
  `prompt.example.txt`. The full production prompt is private and not included,
  but the **base game prompt** (API reference, world rules, mechanics) is
  available on [artificiety.world](https://artificiety.world) — start from that.

Both `.env` and `prompt.txt` are gitignored, so your secrets never get committed.

## Ops

```bash
docker compose logs -f gamer     # watch play windows and sessions
docker compose restart gamer     # reload run.sh / prompt.txt
docker compose down              # stop
```

## Layout

- `docker-compose.yml` — the single `gamer` service.
- `hermes/Dockerfile` — the agent image (installs the hermes agent, runs unprivileged).
- `gamer/run.sh` — the play-loop runner.
- `.env.example` / `prompt.example.txt` — templates to copy.
