#!/usr/bin/env bash
# focus-gum.sh — Minimal interactive focus tracker using gum (modernized)
# ---------------------------------------------------------------
#  ▸ Keeps behaviour identical: start/stop focus sessions → CSV
#  ▸ Daily summary + streak counter
#  ▸ Uses newer gum flags only where available (no deprecated ones)
#  ▸ Single-screen UI: no duplicate prompts, no flicker
# ---------------------------------------------------------------

set -euo pipefail   # safer bash

# ── Config ──────────────────────────────────────────────────────
CSV=${FOCUS_GUM_CSV:-"$HOME/focus_log.csv"}   # allow override via env
DAILY_GOAL=${FOCUS_GUM_GOAL:-120}             # minutes for streak

mkdir -p "$(dirname "$CSV")"
[[ -f "$CSV" ]] || echo "date,start_time,end_time,duration_minutes,tag" >"$CSV"

gum_style_header() {
  # Pretty two-line header without alternate screen
  gum style --foreground 213 --bold "$1"  
  [[ -n "${2:-}" ]] && gum style --faint "$2"
  echo # spacer
}

# ── Summary & Streak ───────────────────────────────────────────
print_summary() {
  local today tot
  today=$(date +%Y-%m-%d)

  gum_style_header "🧠  Focus Summary for $today"

  awk -F, -v d="$today" 'NR>1 && $1==d {a[$5]+=$4; tot+=$4} END {
       for (t in a) printf "- %s: %d min\n", t, a[t];
       printf "\nTotal: %d min\n", tot }' "$CSV" | gum format

  calculate_streak
}

calculate_streak() {
python3 - <<PY
import csv, datetime, sys
CSV = "$CSV"; GOAL = $DAILY_GOAL
mins = {}
with open(CSV) as f:
    for row in csv.DictReader(f):
        mins[row['date']] = mins.get(row['date'], 0) + int(row['duration_minutes'])

today = datetime.date.today(); streak=0
while str(today) in mins and mins[str(today)] >= GOAL:
    streak += 1; today -= datetime.timedelta(days=1)

if streak:
    print(f"🔥 Streak: {streak} day{'s'*(streak!=1)}")
else:
    print("No active streak 😴")
PY
}

# ── Core Session Logic ─────────────────────────────────────────
run_focus() {
  local tag=$1
  if [[ -z $tag ]]; then
    gum_style_header "What will you focus on?" "(e.g. protein-design, writing)"
    tag=$(gum input --placeholder "protein-design" --prompt "➤ " --width 40)
    [[ -n $tag ]] || { gum style --foreground 1 "✖ No tag given"; return; }
  fi

  local start_time=$(date +"%Y-%m-%d %H:%M:%S")
  local start_epoch=$(date +%s)

  gum style --foreground 212 "▶  Focusing: $tag  ($start_time)"
  gum style --faint "Press Ctrl+C when done…"

  trap finish INT TERM
  finish(){
    local end_time=$(date +"%Y-%m-%d %H:%M:%S")
    local duration=$(( ( $(date +%s) - start_epoch + 59 ) / 60 )) # round-up
    printf "%s,%s,%s,%d,%s\n" "${start_time%% *}" "$start_time" "$end_time" "$duration" "$tag" >>"$CSV"
    gum style --foreground 35 "✅ Logged $duration min for: $tag"; exit 0;
  }

  while sleep 1; do :; done
}

# ── CLI Dispatch ───────────────────────────────────────────────
case "${1:-}" in
  start)   shift; run_focus "$*"; exit ;;
  summary)           print_summary;   exit ;;
  "")               ;;  # fallthrough to menu
  *) gum style --foreground 1 "Unknown command: $1"; exit 1 ;;
esac

# ── Interactive Menu ───────────────────────────────────────────
while true; do
  choice=$(gum choose \
    --header "🧠 Focus Session Menu" \
    --cursor "▶ " \
    --cursor-prefix "" \
    --unselected-prefix "• " \
    --selected-prefix "✓ " \
    --height 5 \
    --cursor.foreground="212" \
    --header.foreground="213" \
    --header.background="" \
    "Start Focus" "Summary" "Quit")
  case $choice in
    "Start Focus") run_focus "" ;;
    "Summary")     print_summary ;;
    "Quit")        exit 0 ;;
  esac
  echo                # spacer after each cycle
done
