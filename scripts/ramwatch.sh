#!/usr/bin/env bash
set -euo pipefail

# ---- Tunables (env overrides allowed) ----
INTERVAL="${INTERVAL:-15}"        # seconds between checks
THRESH_MB="${THRESH_MB:-1024}"    # auto act if free RAM < this (MB)
MP_FREE_PCT="${MP_FREE_PCT:-24}"  # backstop on memory_pressure free %
COOLDOWN_SEC="${COOLDOWN_SEC:-60}"

# ---- Paths ----
ATLAS="${HOME}/.atlas/ramwatch"
LOGDIR="${ATLAS}/logs"
LOGFILE="${LOGDIR}/ramwatch.log"
ERRFILE="${LOGDIR}/ramwatch.err"
LOCK="${ATLAS}/.lock"
STAMP="${ATLAS}/.last_act"

mkdir -p "${LOGDIR}"

log(){  printf "[RAMwatch] %s\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ) $*" >>"$LOGFILE"; }
err(){  printf "[RAMwatch] %s\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ) $*" >>"$ERRFILE"; }

free_mb(){ vm_stat | awk '/Pages free/ {gsub("\\.","",$3); printf "%.0f", $3*4096/1024/1024}'; }
mp_free(){ memory_pressure | awk -F'[[:space:]]|:' '/System-wide memory free percentage/ {print $6+0}'; }

purge_disk(){
  if command -v /usr/sbin/purge >/dev/null 2>&1; then
    if /usr/sbin/purge >/dev/null 2>&1; then log "TIER1 purge"; else log "TIER1 purge skipped (not permitted)"; fi
  else
    log "TIER1 purge unavailable"
  fi
}

close_apps(){
  local closed=()
  # Customize the list by setting TIER2_LIST env; defaults:
  local list="${TIER2_LIST:-Chrome
Slack}"
  while IFS= read -r app; do
    [[ -z "$app" ]] && continue
    if pkill -x "$app" >/dev/null 2>&1; then closed+=("$app"); fi
  done <<< "$list"
  [[ ${#closed[@]} -gt 0 ]] && log "TIER2 closed apps: ${closed[*]}" || log "TIER2 none"
}

regex_reclaim(){
  # Customize with TIER3_REGEX; default targets chatty helpers
  local rx="${TIER3_REGEX:-Google Chrome Helper \\(Renderer\\)|java|node}"
  local killed=()
  while read -r pid cmd; do
    kill -9 "$pid" >/dev/null 2>&1 && killed+=("$pid:$cmd")
  done < <(ps axo pid,comm,args | egrep -i "$rx" | egrep -v "egrep|ramwatch")
  [[ ${#killed[@]} -gt 0 ]] && log "TIER3 reclaimed via targeted/regex/large-kill: ${#killed[@]}" || true
}

act_once(){
  local mb mp
  mb=$(free_mb)
  mp=$(mp_free || echo 100)
  log "FREE_MB:$mb | MP_free%:$mp | THRESH_MB:$THRESH_MB | THRESH_MP%:$MP_FREE_PCT"
  if (( mb < THRESH_MB || mp < MP_FREE_PCT )); then
    purge_disk
    mb=$(free_mb); mp=$(mp_free || echo 100); log "POST TIER1 FREE_MB:$mb | MP_free%:$mp"
    if (( mb < THRESH_MB || mp < MP_FREE_PCT )); then
      close_apps
      mb=$(free_mb); mp=$(mp_free || echo 100); log "POST TIER2 FREE_MB:$mb | MP_free%:$mp"
      if (( mb < THRESH_MB || mp < MP_FREE_PCT )); then
        regex_reclaim
      fi
    fi
  fi
}

cooldown(){
  local now last
  now=$(date +%s)
  last=$(cat "$STAMP" 2>/dev/null || echo 0)
  if (( now - last < COOLDOWN_SEC )); then log "cooldown, skipping"; return 1; fi
  echo "$now" > "$STAMP"; return 0
}

main_loop(){
  while :; do
    if cooldown; then act_once; fi
    sleep "$INTERVAL"
  done
}

# Single-instance if 'flock' exists; otherwise continue without locking.
mkdir -p "$(dirname "$LOCK")"
if command -v flock >/dev/null 2>&1; then
  flock -n "$LOCK" -c "$0 internal" && exit 0 || { log "another instance is running"; exit 0; }
fi
[[ "${1:-}" == "internal" ]] && main_loop || main_loop
