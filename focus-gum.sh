#!/usr/bin/env bash
# focus-gum.sh — Minimal interactive focus tracker using gum

set -euo pipefail  # Exit on errors, undefined vars, pipe failures

# Configuration
CSV="$HOME/focus_log.csv"
DAILY_GOAL=120 # minutes required to count toward streak

# Initialize CSV file
mkdir -p "$(dirname "$CSV")"
[[ -f "$CSV" ]] || echo "date,start_time,end_time,duration_minutes,tag" > "$CSV"

########################################
# ── Helpers ───────────────────────────
########################################
print_summary() {
    local today
    today=$(date +%Y-%m-%d)
    
    gum format <<< "# 🧠 Focus Summary for $today"
    
    # Aggregate minutes per tag for today
    awk -F',' -v d="$today" '
        NR > 1 && $1 == d {
            tags[$5] += $4
            total += $4
        }
        END {
            for (tag in tags) {
                printf "- %s: %d min\n", tag, tags[tag]
            }
            printf "\nTotal: %d min\n", total
        }' "$CSV" | gum format
    
    calculate_streak
}

calculate_streak() {
    python3 -c "
import csv
from datetime import datetime, timedelta

goal = $DAILY_GOAL
today = datetime.now().date()
daily_minutes = {}

try:
    with open('$CSV') as f:
        reader = csv.DictReader(f)
        for row in reader:
            day = row['date']
            minutes = int(row['duration_minutes'])
            daily_minutes[day] = daily_minutes.get(day, 0) + minutes
except FileNotFoundError:
    pass

# Calculate streak
streak = 0
current_day = today
while str(current_day) in daily_minutes and daily_minutes[str(current_day)] >= goal:
    streak += 1
    current_day -= timedelta(days=1)

if streak > 0:
    day_word = 'day' if streak == 1 else 'days'
    print(f'🔥 Streak: {streak} {day_word}')
else:
    print('No active streak 😴')
"
}

########################################
# ── Focus Session ─────────────────────
########################################
run_focus() {
    local tag="$1"
    
    # Get focus tag if not provided
    if [[ -z "$tag" ]]; then
        echo "What will you focus on?"
        tag=$(gum input)
        [[ -n "$tag" ]] || { echo "Focus tag required"; return 1; }
    fi
    
    # Record start time
    local start_time start_epoch
    start_time=$(date +"%Y-%m-%d %H:%M:%S")
    start_epoch=$(date +%s)
    
    gum style --foreground 212 "▶️ Focusing: $tag ($start_time)"
    echo "Press Ctrl+C when done…"
    
    # Set up cleanup on interrupt
    local session_completed=false
    cleanup() {
        if [[ "$session_completed" == "false" ]]; then
            local end_time end_epoch duration date_only
            end_time=$(date +"%Y-%m-%d %H:%M:%S")
            end_epoch=$(date +%s)
            duration=$(( (end_epoch - start_epoch + 59) / 60 ))  # Round up to nearest minute
            date_only=$(date +%Y-%m-%d)
            
            # Log the session
            echo "$date_only,$start_time,$end_time,$duration,$tag" >> "$CSV"
            gum style --foreground 35 "✅ Logged $duration min for: $tag"
            session_completed=true
        fi
        exit 0
    }
    trap cleanup INT TERM
    
    # Keep session active
    while true; do 
        sleep 1
    done
}

########################################
# ── CLI Dispatcher ────────────────────
########################################
case "${1:-}" in
    start) 
        shift
        run_focus "$*"
        ;;
    summary) 
        print_summary
        ;;
    "") 
        # No args → fall through to interactive menu
        ;;
    *) 
        echo "Usage: $0 [start [tag]|summary]" >&2
        exit 1
        ;;
esac

########################################
# ── Interactive Menu ──────────────────
########################################
while true; do
    choice=$(gum choose "🧠 Start Focus" "📊 Summary" "❌ Quit")
    
    case "$choice" in
        "🧠 Start Focus") 
            run_focus ""
            ;;
        "📊 Summary") 
            print_summary
            echo  # Add spacing after summary
            ;;
        "❌ Quit") 
            exit 0
            ;;
    esac
done