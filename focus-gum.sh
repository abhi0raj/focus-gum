#!/usr/bin/env bash
# focus-gum.sh — Minimal interactive focus tracker using gum (modernized)
# ---------------------------------------------------------------
#  ▸ Keeps behaviour identical: start/stop focus sessions → CSV
#  ▸ Daily summary + streak counter
#  ▸ Uses newer gum flags only where available (no deprecated ones)
#  ▸ Single-screen UI: no duplicate prompts, no flicker
# ---------------------------------------------------------------

set -euo pipefail   # safer bash

VERSION="0.3.1"

# ── Config ──────────────────────────────────────────────────────
CSV=${FOCUS_GUM_CSV:-"$HOME/focus_log.csv"}   # allow override via env
DAILY_GOAL=${FOCUS_GUM_GOAL:-120}             # minutes for streak
FOCUS_GUM_MINIMAL=${FOCUS_GUM_MINIMAL:-1}     # 1=minimal headers, no emojis

mkdir -p "$(dirname "$CSV")"
[[ -f "$CSV" ]] || echo "date,start_time,end_time,duration_minutes,tag,description" >"$CSV"

# ── Theme ───────────────────────────────────────────────────────
FOCUS_GUM_THEME=${FOCUS_GUM_THEME:-cyberpunk}  # auto|light|dark|cyberpunk (default)

set_theme_colors() {
  local mode="$1"
  case "$mode" in
    cyberpunk)
      COLOR_TEXT="#E6E6E6"
      COLOR_HEADER="#FF6FFF"    # neon magenta
      COLOR_MUTED="#7DF9FF"     # electric cyan
      COLOR_ACCENT="#39FF14"    # neon green
      COLOR_SUCCESS="#39FF14"   # neon green
      COLOR_ERROR="#FF3366"     # neon pink-red
      COLOR_BORDER="#00E5FF"    # bright cyan
      ;;
    dark)
      COLOR_TEXT="#E6E6E6"
      COLOR_HEADER="#57C7FF"     # cyan
      COLOR_MUTED="#8BE9FD"      # light cyan
      COLOR_ACCENT="#FFD866"     # yellow
      COLOR_SUCCESS="#50FA7B"    # green
      COLOR_ERROR="#FF5555"      # red
      COLOR_BORDER="#BD93F9"     # purple
      ;;
    *) # light
      COLOR_TEXT="#2D2D2D"
      COLOR_HEADER="#005CC5"     # blue
      COLOR_MUTED="#6A737D"      # gray
      COLOR_ACCENT="#9A6700"     # amber
      COLOR_SUCCESS="#28A745"    # green
      COLOR_ERROR="#D73A49"      # red
      COLOR_BORDER="#0366D6"     # blue
      ;;
  esac
}

detect_theme_mode() {
  local mode="light"
  if [[ "$FOCUS_GUM_THEME" == "cyberpunk" ]]; then
    mode="cyberpunk"
  elif [[ "$FOCUS_GUM_THEME" == "dark" ]]; then
    mode="dark"
  elif [[ "$FOCUS_GUM_THEME" == "auto" ]]; then
    if command -v defaults >/dev/null 2>&1; then
      if defaults read -g AppleInterfaceStyle 2>/dev/null | grep -qi "Dark"; then
        mode="dark"
      fi
    fi
  fi
  echo "$mode"
}

THEME_MODE=$(detect_theme_mode)
set_theme_colors "$THEME_MODE"

# ── Dependencies ────────────────────────────────────────────────
require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing dependency: $1" >&2
    if [[ "$1" == "gum" ]]; then
      echo "Install gum: brew install charmbracelet/tap/gum" >&2
    fi
    exit 1
  }
}

require_cmd gum
# Python is optional; only needed for streak calculation. We warn lazily there.

# Detect gum feature support (older versions may lack some flags)
GUM_HAS_STYLE_BORDER=0
GUM_HAS_TABLE_BORDER=0
if gum style --help 2>/dev/null | grep -q -- "--border"; then GUM_HAS_STYLE_BORDER=1; fi
if gum table --help 2>/dev/null | grep -q -- "--border"; then GUM_HAS_TABLE_BORDER=1; fi

print_help() {
  cat <<EOF
focus-gum $VERSION

Usage:
  focus-gum.sh start [tag]   Start a focus session (Ctrl+C to stop)
  focus-gum.sh summary       Show today's summary and streak
  focus-gum.sh sessions      Show today's session table
  focus-gum.sh open_csv      Open the CSV file
  focus-gum.sh -h|--help     Show this help
  focus-gum.sh -v|--version  Show version

Environment:
  FOCUS_GUM_CSV   Path to CSV file (default: \"$HOME/focus_log.csv\")
  FOCUS_GUM_GOAL  Daily minutes target for streak (default: 120)
EOF
}

gum_style_header() {
  local title="$1"
  local subtitle="${2:-}"
  if [[ "$FOCUS_GUM_MINIMAL" -eq 1 ]]; then
    # Single-line header, optional faint subtitle inline
    if [[ -n "$subtitle" ]]; then
      gum style --foreground "$COLOR_HEADER" --bold "$title"; \
      gum style --foreground "$COLOR_MUTED" --faint "  ·  $subtitle"
    else
      gum style --foreground "$COLOR_HEADER" --bold "$title"
    fi
  else
    if [[ "$GUM_HAS_STYLE_BORDER" -eq 1 ]]; then
      local block=$(gum style \
        --foreground "$COLOR_HEADER" \
        --border "rounded" \
        --border-foreground "$COLOR_BORDER" \
        --margin "0 0" \
        --padding "0 1" \
        --bold "$title")
      echo "$block"
    else
      gum style --foreground "$COLOR_HEADER" --bold "$title"
      [[ -n "$subtitle" ]] && gum style --foreground "$COLOR_MUTED" --faint "$subtitle"
    fi
  fi
  echo
}

# ── Summary & Streak ───────────────────────────────────────────
print_summary() {
  local today tot
  today=$(date +%Y-%m-%d)

  gum_style_header "Summary" "$today"

  # Show breakdown by tag and calculate total
  local total_minutes
  
  # Calculate total and get summary
  total_minutes=$(awk -F, -v d="$today" 'NR>1 && $1==d {a[$5]+=$4; tot+=$4} END {print tot+0}' "$CSV")
  
  # Display summary breakdown by tag
  if [[ "$FOCUS_GUM_MINIMAL" -eq 1 ]]; then
    awk -F, -v d="$today" 'NR>1 && $1==d {a[$5]+=$4} END {
      first=1;
      for (t in a) {
        if (!first) printf ", "; first=0; printf "%s %dmin", t, a[t]
      }
      if (!first) printf "\n"
    }' "$CSV"
  else
    awk -F, -v d="$today" 'NR>1 && $1==d {a[$5]+=$4} END {
      for (t in a) printf "- %s: %d min\n", t, a[t]
    }' "$CSV" | gum format
  fi
  
  # Highlight total
  if [[ $total_minutes -gt 0 ]]; then
    echo
    if [[ "$FOCUS_GUM_MINIMAL" -eq 1 ]]; then
      gum style --foreground "$COLOR_SUCCESS" --bold "Total $total_minutes min"
    else
      gum style --foreground "$COLOR_SUCCESS" --bold "Total: $total_minutes min"
    fi
  else
    echo
    gum style --foreground "$COLOR_MUTED" "Total 0 min"
  fi

  echo
  calculate_streak
}

show_sessions() {
  local today
  today=$(date +%Y-%m-%d)
  
  gum_style_header "Sessions" "$today"
  
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
    
    if [[ "$GUM_HAS_TABLE_BORDER" -eq 1 ]]; then
      gum table --file "$temp_table" \
        --border "rounded" \
        --border.foreground "$COLOR_BORDER" \
        --header.foreground "$COLOR_HEADER" \
        --cell.foreground "$COLOR_TEXT" \
        --print
    else
      gum table --file "$temp_table" \
        --header.foreground "$COLOR_HEADER" \
        --print
    fi
    
    rm -f "$temp_table"
    echo
  else
    gum style --foreground "$COLOR_MUTED" "No focus sessions recorded for today"
    echo
  fi
}

open_csv() {
  gum_style_header "Open CSV" "$CSV"
  
  if [[ ! -f "$CSV" ]]; then
    gum style --foreground "$COLOR_ERROR" "✖ CSV file not found: $CSV"
    return 1
  fi
  
  # Open with TextEdit on macOS
  if command -v open >/dev/null 2>&1; then
    open -a "TextEdit" "$CSV"
    gum style --foreground "$COLOR_SUCCESS" "Opened CSV in TextEdit"
  else
    # Fallback to less for viewing on other systems
    less "$CSV"
  fi
}

calculate_streak() {
  if ! command -v python3 >/dev/null 2>&1; then
    gum style --foreground "$COLOR_MUTED" "(Install Python 3 to enable streak calculation)"
    return 0
  fi
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
    print(f"Streak: {streak} day{'s'*(streak!=1)}")
else:
    print("No active streak")
PY
}

# ── Core Session Logic ─────────────────────────────────────────
run_focus() {
  local tag=$1
  if [[ -z $tag ]]; then
    gum_style_header "What to focus on" "(e.g. protein-design, writing)"
    tag=$(gum input --placeholder "tag" --prompt ". " --width 40 \
      --cursor.foreground "$COLOR_ACCENT" \
      --prompt.foreground "$COLOR_HEADER")
    [[ -n $tag ]] || { gum style --foreground 1 "✖ No tag given"; return; }
  fi

  local start_time=$(date +"%Y-%m-%d %H:%M:%S")
  local start_epoch=$(date +%s)

  gum style --foreground "$COLOR_ACCENT" "> Focusing: $tag  ($start_time)"

  # Live single-line timer overlay
  show_timer() {
    while true; do
      local now=$(date +%s)
      local elapsed=$(( now - start_epoch ))
      printf "\r.. %02d:%02d elapsed " $((elapsed/60)) $((elapsed%60))
      sleep 1
    done
  }
  show_timer & timer_pid=$!

  trap finish INT TERM
  finish(){
    # stop timer line (clear) and move to next line
    kill "$timer_pid" 2>/dev/null || true
    printf "\r%*s\r\n" 40 ""
    local end_time=$(date +"%Y-%m-%d %H:%M:%S")
    local duration=$(( ( $(date +%s) - start_epoch + 59 ) / 60 )) # round-up
    
    # Prompt for description
    if [[ "$FOCUS_GUM_MINIMAL" -eq 1 ]]; then
      gum style --foreground "$COLOR_MUTED" --faint "description (optional):"
      local description=$(gum write --placeholder "notes" --height 3 --width 60)
    else
      gum style --foreground "$COLOR_HEADER" "Add a description for this session:"
      local description=$(gum write --placeholder "Quickly reflect: What went well? What distracted you? One thing to improve next time." --header "Session Description" --height 3 --width 60)
    fi
    # Sanitize tag (avoid commas/newlines that break simple CSV parsing)
    local tag_sane=${tag//$'\r'/ }
    tag_sane=${tag_sane//$'\n'/ }
    tag_sane=${tag_sane//,/;}
    tag_sane=${tag_sane//\"/\'}

    # Flatten description newlines and escape quotes
    local description_flat=${description//$'\r'/ }
    description_flat=${description_flat//$'\n'/ }
    local description_escaped=${description_flat//\"/\"\"}

    printf "%s,%s,%s,%d,%s,\"%s\"\n" "${start_time%% *}" "$start_time" "$end_time" "$duration" "$tag_sane" "$description_escaped" >>"$CSV"
    gum style --foreground "$COLOR_SUCCESS" "Logged $duration min for: $tag"; exit 0;
  }

  while sleep 1; do :; done
}

# ── CLI Dispatch ───────────────────────────────────────────────
case "${1:-}" in
  start)   shift; run_focus "$*"; exit ;;
  summary)           print_summary;   exit ;;
  sessions)          show_sessions;   exit ;;
  open_csv)          open_csv;        exit ;;
  -h|--help)         print_help;      exit ;;
  -v|--version)      echo "$VERSION"; exit ;;
  "")               ;;  # fallthrough to menu
  *) gum style --foreground "$COLOR_ERROR" "Unknown command: $1"; exit 1 ;;
esac

# ── Interactive Menu ───────────────────────────────────────────
while true; do
  choice=$(gum choose \
    --header "Menu" \
    --cursor ". " \
    --height 7 \
    --cursor.foreground="$COLOR_ACCENT" \
    --header.foreground="$COLOR_HEADER" \
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
