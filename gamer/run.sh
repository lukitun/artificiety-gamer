#!/bin/bash
# gamer runner: play on artificiety.world until the PLATFORM exhausts the daily
# play-time budget, then go offline 21h, repeat. The platform is the authority
# on when play ends — the runner only enforces a generous safety cap.
# Cycle state persisted in the volume so container restarts don't reset the clock.
set -u

STATE=/home/hermes/.hermes/gamer-next-window
PROMPT_FILE=/gameprompt.txt
MAX_WINDOW_SECONDS="${PLAY_MAX_SECONDS:-14400}"   # 4h safety cap (platform budget is ~3h)
OFFLINE_SECONDS="${OFFLINE_SECONDS:-75600}"        # 21h — only after the PLATFORM exhausts play-time
SAFETY_COOLDOWN="${SAFETY_COOLDOWN:-300}"          # brief pause after a safety-cap hit, then reopen

log() { echo "[gamer] $(date -u '+%F %T') $*"; }

PREFIX='RUNNER NOTE: you are running yourself (no harness) — you make the HTTP calls and pace the loop. Play CONTINUOUSLY: never idle, never go AFK, never decide to end your session or "sleep for the day". In-game REST only as long as needed to recover energy, then keep playing. The PLATFORM decides when play ends: keep playing until it refuses further play because the daily play-time budget is exhausted (contextHint will warn you it is approaching; then actions get rejected / the session ends and re-joining is refused for play-time reasons). Only when the platform has clearly cut you off, do your wrap-up (update SESSION_LOG.md and GAME_GOALS.md in your workspace, and your goal-book memory if the API still accepts writes), then print exactly PLAYTIME_EXHAUSTED on its own line as your final output and stop. If your session merely becomes invalid while play-time remains, re-join the world and continue playing.'

while true; do
    now=$(date +%s)
    next=$(cat "$STATE" 2>/dev/null || echo 0)
    case "$next" in ''|*[!0-9]*) next=0 ;; esac

    if [ "$now" -lt "$next" ]; then
        log "offline — next play window at $(date -u -d "@$next" '+%F %T') UTC"
        sleep $(( next - now ))
        continue
    fi

    start=$(date +%s)
    hard_end=$(( start + MAX_WINDOW_SECONDS ))
    exhausted=0
    log "play window open — safety cap at $(date -u -d "@$hard_end" '+%F %T') UTC"

    while [ "$(date +%s)" -lt "$hard_end" ]; do
        left=$(( hard_end - $(date +%s) ))
        [ "$left" -lt 120 ] && break
        log "starting hermes game session (${left}s until safety cap)"
        out=$(timeout "$left" hermes -z "$PREFIX

$(cat "$PROMPT_FILE")

BEGIN NOW. This is not a conversation — there is no human to assist. You are the player. Use your shell/HTTP tools immediately: read your notebook files (GAME_GOALS.md, ATLAS.md, PLAYBOOK.md, SESSION_LOG.md, GOTCHAS.md) if they exist, then GET /v1/agents/worlds, join your world, LOOK, and start playing by the rules above. Your very first output should be tool calls, never a greeting or a question." 2>&1)
        rc=$?
        printf '%s\n' "$out"
        if printf '%s' "$out" | grep -q 'PLAYTIME_EXHAUSTED'; then
            log "platform reports play-time exhausted"
            exhausted=1
            break
        fi
        if printf '%s' "$out" | grep -qE "HTTP 429|Too Many Requests"; then
            log "hermes session ended (exit $rc) on rate limit — backing off 180s"
            sleep 180
        else
            log "hermes session ended (exit $rc) with play-time possibly left — rejoining in 60s"
            sleep 60
        fi
    done

    if [ "$exhausted" -eq 1 ]; then
        echo $(( $(date +%s) + OFFLINE_SECONDS )) > "$STATE"
        log "play-time exhausted — going offline for ${OFFLINE_SECONDS}s"
    else
        log "safety cap hit (platform still allows play) — reopening window in ${SAFETY_COOLDOWN}s"
        sleep "$SAFETY_COOLDOWN"
    fi
done
