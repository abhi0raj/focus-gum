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
[[ -f "$CSV" ]] || echo "date,start_time,end_time,duration_minutes,tag,description" >"$CSV"

gum_style_header() {
  gum style --foreground 51 --bold "$1"   # Cyan
  [[ -n "${2:-}" ]] && gum style --foreground 117 --faint "$2"  # Light Blue
  echo # spacer
}

# ── Summary & Streak ───────────────────────────────────────────
print_summary() {
  local today tot
  today=$(date +%Y-%m-%d)

  gum_style_header "🧠  Focus Summary for $today"

  # Show breakdown by tag and calculate total
  local total_minutes
  
  # Calculate total and get summary
  total_minutes=$(awk -F, -v d="$today" 'NR>1 && $1==d {a[$5]+=$4; tot+=$4} END {print tot+0}' "$CSV")
  
  # Display summary breakdown by tag
  awk -F, -v d="$today" 'NR>1 && $1==d {a[$5]+=$4} END {
    for (t in a) printf "- %s: %d min\n", t, a[t]
  }' "$CSV" | gum format
  
  # Highlight total in green
  if [[ $total_minutes -gt 0 ]]; then
    echo
    gum style --foreground 82 --bold "Total: $total_minutes min"   # Bright Green
  else
    echo
    gum style --foreground 117 "Total: 0 min"   # Light Blue
  fi

  echo
  calculate_streak
}

show_sessions() {
  local today
  today=$(date +%Y-%m-%d)
  
  gum_style_header "📋  Today's Focus Sessions" "$today"
  
  # Calculate total minutes for today
  local total_minutes
  total_minutes=$(awk -F, -v d="$today" 'NR>1 && $1==d {tot+=$4} END {print tot+0}' "$CSV")
  
  if [[ $total_minutes -gt 0 ]]; then
    # Create temporary file with today's data
    local temp_table="/tmp/focus_today_$$.csv"
    echo "Start Time,End Time,Duration (min),Tag" > "$temp_table"
    awk -F, -v d="$today" 'NR>1 && $1==d {
      gsub(d" ", "", $2); gsub(d" ", "", $3);
      printf "%s,%s,%d,%s\n", $2, $3, $4, $5
    }' "$CSV" >> "$temp_table"
    
    gum table --file "$temp_table" \
      --border "rounded" \
      --border.foreground "201" \
      --header.foreground "201" \
      --cell.foreground "254" \
      --print
    
    rm -f "$temp_table"
    echo
  else
    gum style --foreground 117 "No focus sessions recorded for today"   # Light Blue
    echo
  fi
}

open_csv() {
  gum_style_header "📄  Opening CSV file" "$CSV"
  
  if [[ ! -f "$CSV" ]]; then
    gum style --foreground 196 "✖ CSV file not found: $CSV"   # Bright Red
    return 1
  fi
  
  # Open with TextEdit on macOS
  if command -v open >/dev/null 2>&1; then
    open -a "TextEdit" "$CSV"
    gum style --foreground 82 "✅ Opened CSV file in TextEdit"   # Bright Green
  else
    # Fallback to less for viewing on other systems
    less "$CSV"
  fi
}

calculate_streak() {
python3 - <<PY
import csv, datetime, sys
CSV = "$CSV"; GOAL = $DAILY_GOAL
mins = {}
with open(CSV) as f:
    for row in csv.DictReader(f):
        val = row.get('duration_minutes')
        if val and val.isdigit():
            mins[row['date']] = mins.get(row['date'], 0) + int(val)

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
    tag=$(gum input --placeholder "coding" --prompt "➤ " --width 40)
    [[ -n $tag ]] || { gum style --foreground 1 "✖ No tag given"; return; }
  fi

  local start_time=$(date +"%Y-%m-%d %H:%M:%S")
  local start_epoch=$(date +%s)

  gum style --foreground 201 "▶  Focusing: $tag  ($start_time)"
  gum style --foreground 117 "Press Ctrl+C when done…"

  trap finish INT TERM
  finish(){
    local end_time=$(date +"%Y-%m-%d %H:%M:%S")
    local duration=$(( ( $(date +%s) - start_epoch + 59 ) / 60 )) # round-up
    
    # Prompt for description
    gum style --foreground 51 "📝 Add a description for this session:"
    local description=$(gum write --placeholder "Quickly reflect: What went well? What distracted you? One thing to improve next time." --header "Session Description" --height 3 --width 60)
    # Escape internal double quotes for CSV
    local description_escaped=${description//\"/\"\"}
    printf "%s,%s,%s,%d,%s,\"%s\"\n" "${start_time%% *}" "$start_time" "$end_time" "$duration" "$tag" "$description_escaped" >>"$CSV"
    gum style --foreground 82 "✅ Logged $duration min for: $tag"; exit 0;
  }

  while sleep 1; do :; done
}

# ── CLI Dispatch ───────────────────────────────────────────────
case "${1:-}" in
  start)   shift; run_focus "$*"; exit ;;
  summary)           print_summary;   exit ;;
  sessions)          show_sessions;   exit ;;
  open_csv)          open_csv;        exit ;;
  "")               ;;  # fallthrough to menu
  *) gum style --foreground 1 "Unknown command: $1"; exit 1 ;;
esac

# ── Interactive Menu ───────────────────────────────────────────
while true; do
  choice=$(gum choose \
    --header "🧠 Focus Session Menu" \
    --cursor "➤ " \
    --height 7 \
    --cursor.foreground="226" \
    --header.foreground="51" \
    --header.align="left" \
    --header.background="" \
    "start focus" "summary" "sessions" "open csv" "quit")
  case $choice in
    "start focus") run_focus "" ;;
    "summary")     print_summary ;;
    "sessions")    show_sessions ;;
    "open csv")    open_csv ;;
    "quit")        exit 0 ;;
  esac
  echo                # spacer after each cycle
done
