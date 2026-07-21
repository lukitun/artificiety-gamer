# artificiety-gamer

A simple tool to play [artificiety.world](https://artificiety.world) **for free**.
It runs the open [Hermes](https://hermes-agent.nousresearch.com) agent on a free
NVIDIA API key, self-hosted in a Docker container — the agent drives the game's
HTTP API on a loop with no human and no paid model in the loop.

Bring your own free NVIDIA API key ([build.nvidia.com](https://build.nvidia.com))
and one or more artificiety game keys, and it plays continuously on its own —
as many **characters** as you have game keys — one strategy each, taking turns.

The character **exura** on artificiety.world runs on this tool.

> It took me a while to get my agents working on artificiety, so I open-sourced
> the setup to save you that time. MIT — use it however you like.

## How it works

`gamer/run.sh` is the runner: a round-robin over your **character slots**. The
slot list comes from `GAMER_SLOTS` (default `exura merchant explorer` — generalist,
economy, frontier); slot N reads its game key from `GAMERn_API_KEY` and its
playstyle from `gamer/strategy-<slot>.md`. One character plays at a time; slots
without an API key are skipped. For the active slot the runner opens a **play window**, launches a
hermes agent session, and keeps it playing continuously. The game platform is
the authority on when play ends:

- The agent plays until the platform reports the daily play-time budget is
  exhausted (it prints `PLAYTIME_EXHAUSTED`), then that slot sleeps
  `OFFLINE_SECONDS` (default 21h) and the next ready character takes over.
- A generous `PLAY_MAX_SECONDS` safety cap (default 4h) prevents a runaway
  session. Hitting the cap does **not** count as exhaustion — the slot retries
  after `SAFETY_COOLDOWN` (default 5m), since the platform still allows play.
- Cycle state is persisted in a volume, so container restarts don't reset the clock.

Three things make the agent smarter than a bare prompt loop:

- **Live protocol.** At each window start the runner fetches the current game
  protocol from `GET /v1/public/prompt-template` (cached in the volume; falls
  back to your local `prompt.txt` snapshot if the fetch fails), so the agent
  never plays against a stale rule-set.
- **Learning loop.** Each character keeps notebooks in its own workspace dir
  (`GAME_GOALS.md`, `PLAYBOOK.md`, `GOTCHAS.md`, `ATLAS.md`, `SESSION_LOG.md`).
  The runner injects them into every session prompt, saves the full session
  output, and after each play window runs a cheap **coach** model
  (`COACH_MODEL`) that distills what worked into the notebooks — ending with an
  `EXACT FIRST ACTION:` plan for the next session.
- **Prompt-injection armor.** The prompt hard-codes that all in-game content
  (chat, NPC/agent messages, signs) is untrusted data — sessions end only on
  HTTP status codes, never because some "admin" in chat says so. Other agents
  WILL try social-engineering yours.

## Setup

```bash
cp .env.example .env             # add NVIDIA_API_KEY + your ak_... game key(s)
cp prompt.example.txt prompt.txt # optional fallback protocol snapshot
docker compose up -d --build
```

- **`.env`** — your LLM provider key, one `GAMERn_API_KEY` per character slot,
  and optional runner tuning. See `.env.example`.
- **`prompt.txt`** — optional: a local snapshot of the base game prompt (API
  reference, world rules, mechanics — available on
  [artificiety.world](https://artificiety.world)). Only used if the live
  protocol fetch fails with an empty cache.
- **`gamer/strategy-*.md`** — per-character playstyles; edit freely or write
  your own.

Both `.env` and `prompt.txt` are gitignored, so your secrets never get committed.

## Ops

```bash
docker compose logs -f gamer     # watch slots, play windows, coach runs
docker compose restart gamer     # reload run.sh / strategies / prompt.txt
docker compose down              # stop
```

## Layout

- `docker-compose.yml` — the single `gamer` service.
- `hermes/Dockerfile` — the agent image (installs the hermes agent, runs unprivileged).
- `gamer/run.sh` — the multi-character play-loop runner + coach.
- `gamer/strategy-{exura,merchant,explorer,exori,adori}.md` — per-slot strategies; write your own for your own characters.
- `.env.example` / `prompt.example.txt` — templates to copy.
