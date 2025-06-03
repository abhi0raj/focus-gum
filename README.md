# focus-gum 🧠

*A minimalist, terminal-native focus tracker built with Bash + [gum](https://github.com/charmbracelet/gum).  
Designed for “monk-mode” deep-work rituals inspired by Cal Newport & James Clear.*

---

## Features
- **Interactive menu** (`gum choose`) to start sessions, view daily summary, or quit.
- **CSV logging** to `~/focus_log.csv`  (`date,start,end,duration_minutes,tag`).
- **Streak tracker** – counts consecutive days ≥ `DAILY_GOAL` minutes.
- **One-line install** – copy the script to `~/bin` & add an alias.
- **Zero dependencies** beyond Bash + gum (Python 3 ships on macOS for the streak calc).

---

## Installation

```bash
brew install charmbracelet/tap/gum    # install gum
mkdir -p ~/bin                        # ensure scripts folder exists
curl -sL https://raw.githubusercontent.com/abhi0raj/focus-gum/main/focus-gum.sh -o ~/bin/focus-gum.sh
chmod +x ~/bin/focus-gum.sh
echo 'alias focus="$HOME/bin/focus-gum.sh"' >> ~/.zshrc
source ~/.zshrc
Usage

focus start <tag>   # quick start (e.g. focus start writing)
focus summary       # today’s totals + streak
focus               # interactive menu
Config

Edit the top of focus-gum.sh to tweak:

CSV="$HOME/focus_log.csv"   # change log location
DAILY_GOAL=120              # minutes required for streak
Roadmap

 Pomodoro countdown overlay
 macOS Do-Not-Disturb toggle on session start
 Weekly Markdown report generator
 Homebrew formula for brew install focus-gum
PRs welcome. 🎉

License

MIT © Abhi Rajendran
