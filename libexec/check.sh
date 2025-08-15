#!/bin/bash
set -u

DIR="$HOME/.atlas/ramwatch"
LOG="$DIR/logs/ram.log"
CFG="$DIR/config.sh"
mkdir -p "$DIR/logs"

# Config with defaults
HARD_FLOOR_MB=5120
CHECK_INTERVAL=30
[ -f "$CFG" ] && . "$CFG"

ts(){ /bin/date -u +'%Y-%m-%dT%H:%M:%SZ'; }

free_mb() {
  /usr/bin/awk -v P="$(/usr/sbin/sysctl -n hw.pagesize)" '
    /Pages free/        {gsub(/\./,"",$3); f=$3}
    /Pages speculative/ {gsub(/\./,"",$3); s=$3}
    END{printf "%d",(f+s)*P/1024/1024}
  ' < <(/usr/bin/vm_stat)
}

purge_once() {
  /usr/bin/sudo -n /usr/sbin/purge >/dev/null 2>&1 || \
  /usr/bin/sudo    /usr/sbin/purge >/dev/null 2>&1
}

while :; do
  fm=$(free_mb)
  if (( fm < HARD_FLOOR_MB )); then
    echo "$(ts) [ramwatch] below floor: free=${fm}MB < target=${HARD_FLOOR_MB}MB → purging…" >>"$LOG"
    for i in {1..60}; do
      purge_once
      sleep 2
      fm2=$(free_mb)
      if (( fm2 >= HARD_FLOOR_MB )); then
        echo "$(ts) [ramwatch] post-purge free=${fm2}MB (target=${HARD_FLOOR_MB}MB)" >>"$LOG"
        break
      fi
      if (( i == 60 )); then
        echo "$(ts) [ramwatch] WARN: after 60 attempts still below floor (free=${fm2}MB < target=${HARD_FLOOR_MB}MB)" >>"$LOG"
      fi
    done
  else
    echo "$(ts) [ramwatch] ok: free=${fm}MB (target=${HARD_FLOOR_MB}MB)" >>"$LOG"
  fi
  sleep "${CHECK_INTERVAL:-30}"
done

#==AGGRESSIVE_MARK==
if [[ $free_mb -lt $FLOOR_MB ]] && [[ ${AGGRESSIVE:-0} -eq 1 ]] && [[ $tries -ge ${GRACE_ATTEMPTS:-30} ]]; then
  top=$(ps axo pid,rss,comm | awk 'NR>1{mb=$2/1024; if(mb>=600) print mb" " $1" " $3}' | sort -nr | egrep -v -- "${KILL_DENY_REGEX:-^$}" | head -n1)
  if [[ -n $top ]]; then
    mb=$(echo "$top" | awk '{print $1}'); pid=$(echo "$top" | awk '{print $2}'); name=$(echo "$top" | cut -d" " -f3-)
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) [ramwatch] AGGRESSIVE: killing pid=$pid ("$mb"MB) name=""$name""" >>"$LOG"
    kill -15 "$pid" 2>/dev/null || true; sleep 3
  fi
fi
