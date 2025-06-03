#!/usr/bin/env bash
# focus-gum.sh — Minimal interactive focus tracker using gum

CSV="$HOME/focus_log.csv"
DAILY_GOAL=120         # minutes required to count toward streak

mkdir -p "$(dirname "$CSV")"
[[ -f "$CSV" ]] || echo "date,start_time,end_time,duration_minutes,tag" > "$CSV"

########################################
# ── Helpers ───────────────────────────
########################################
print_summary() {
  local TODAY total
  TODAY=$(date +%Y-%m-%d)
  gum format <<< "# 🧠 Focus Summary for $TODAY"

  # Aggregate minutes per tag
  awk -F',' -v d="$TODAY" '
    NR>1 && $1==d {a[$5]+=$4; total+=$4}
    END {
      for (t in a) printf "- %s: %d min\n", t, a[t];
      printf "\nTotal: %d min\n", total
    }' "$CSV" | gum format

  calculate_streak
}

calculate_streak() {
python3 - <<PY
import csv, sys
from datetime import datetime, timedelta
goal = $DAILY_GOAL
today = datetime.now().date()
minutes = {}
with open("$CSV") as f:
    for r in csv.DictReader(f):
        day = r["date"]
        minutes[day] = minutes.get(day, 0) + int(r["duration_minutes"])
streak, cur = 0, today
while str(cur) in minutes and minutes[str(cur)] >= goal:
    streak += 1
    cur -= timedelta(days=1)
print("🔥 Streak:" if streak else "No active streak 😴", streak, "day" + ("s" if streak != 1 else ""))
PY
}

########################################
# ── Focus Session ─────────────────────
########################################
run_focus() {
  local TAG="$1"
  if [[ -z "$TAG" ]]; then
    gum format --alignment left <<< "## What will you focus on?\n*(e.g. protein-design, writing)*"
    TAG=$(gum input --placeholder "protein-design" --prompt "➤ ")
  fi

  local START_TIME START_EPOCH
  START_TIME=$(date +"%Y-%m-%d %H:%M:%S")
  START_EPOCH=$(date +%s)

  gum style --foreground 212 "▶️  Focusing: $TAG  ($START_TIME)"
  echo "Press Ctrl+C when done…"

  trap finish INT
  finish() {
      local END_TIME END_EPOCH DURATION DATE
      END_TIME=$(date +"%Y-%m-%d %H:%M:%S")
      END_EPOCH=$(date +%s)
      DURATION=$(( (END_EPOCH - START_EPOCH + 59) / 60 ))
      DATE=$(date +%Y-%m-%d)
      echo "$DATE,$START_TIME,$END_TIME,$DURATION,$TAG" >> "$CSV"
      gum style --foreground 35 "✅  Logged $DURATION min for: $TAG"
      exit 0
  }

  while true; do sleep 1; done
}

########################################
# ── CLI Dispatcher ────────────────────
########################################
case "$1" in
  start)  shift; run_focus "$*"; exit ;;
  summary)       print_summary;        exit ;;
  *) clear ;;
esac

########################################
# ── Interactive Menu ──────────────────
########################################
while true; do
  CHOICE=$(gum choose "🧠 Start Focus" "📊 Summary" "❌ Quit")
  clear
  case "$CHOICE" in
    "🧠 Start Focus") run_focus ;;
    "📊 Summary")     print_summary ;;
    "❌ Quit")        exit 0 ;;
  esac
done