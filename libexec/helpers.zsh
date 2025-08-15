rw_status(){ launchctl print gui/$(id -u)/com.tachyon.ramwatch | egrep 'state|pid|program|LastExitStatus' || true; }
rw_log(){ tail -n 60 -f "$HOME/.atlas/ramwatch/logs/ram.log" 2>/dev/null || true; }
rw_set(){ local mb="${1:-5120}"; local it="${2:-10}"; printf 'HARD_FLOOR_MB=%s\nCHECK_INTERVAL=%s\n' "$mb" "$it" > "$HOME/.atlas/ramwatch/config.sh"; launchctl kickstart -k gui/$(id -u)/com.tachyon.ramwatch; echo "Set floor=${mb}MB interval=${it}s"; }
ramwatch(){ local page_kb=$(vm_stat|awk '/page size of/{print $8}')
  local free_pages=$(vm_stat|awk '/Pages free/{gsub(/[^0-9]/,"",$3);print $3}')
  local spec_pages=$(vm_stat|awk '/Pages speculative/{gsub(/[^0-9]/,"",$3);print $3}')
  local free_mb=$(( ( (free_pages+spec_pages) * page_kb ) / 1024 / 1024 ))
  local floor=$(awk -F= '/^HARD_FLOOR_MB/{print $2}' "$HOME/.atlas/ramwatch/config.sh" 2>/dev/null); [[ -z $floor ]] && floor=4096
  local green=$'\033[32m'; local red=$'\033[31m'; local reset=$'\033[0m'
  local color=$([[ $free_mb -lt $floor ]] && echo "$red" || echo "$green")
  printf 'Free: %s%4d MB%s   Floor: %s MB\n' "$color" "$free_mb" "$reset" "$floor"
  rw_status; tail -n 20 "$HOME/.atlas/ramwatch/logs/ram.log" 2>/dev/null || true; }
# one-shot “what’s slow” snapshot
smooth(){ echo '== swap =='; sysctl vm.swapusage;
  echo '== top RAM hogs ==' ; ps axo pid,rss,comm | awk 'NR>1{printf "%6d  %6.1f MB  %s\n",$1,$2/1024,$3}' | sort -nrk2 | head;
  echo '== top CPU (1s) =='; ps -A -o pid,pcpu,comm | sort -nrk2 | head; }
