#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ICON_DIR="$HOME/Pictures/Icons"
WEBAPP_MANAGER_COMMON="/usr/lib/webapp-manager/common.py"

if [[ ! -f "$WEBAPP_MANAGER_COMMON" ]]; then
  echo "Skipping default web apps because webapp-manager is not installed."
  exit 0
fi

if ! command -v vivaldi >/dev/null 2>&1 && ! command -v vivaldi-stable >/dev/null 2>&1; then
  echo "Skipping default web apps because Vivaldi is not installed."
  exit 0
fi

python3 "$SCRIPT_DIR/create_webapp.py" \
  --name "Amazon Prime Video" \
  --url "https://www.primevideo.com/" \
  --desc "Amazon Prime Video streaming" \
  --browser "Vivaldi" \
  --category "AudioVideo" \
  --icon "$ICON_DIR/prime-video.png"

python3 "$SCRIPT_DIR/create_webapp.py" \
  --name "ChatGPT" \
  --url "https://chatgpt.com/" \
  --desc "OpenAI AI assistant" \
  --browser "Vivaldi" \
  --category "Utility" \
  --icon "$ICON_DIR/chatgpt.png"

python3 "$SCRIPT_DIR/create_webapp.py" \
  --name "Crunchyroll" \
  --url "https://www.crunchyroll.com/" \
  --desc "Anime streaming platform" \
  --browser "Vivaldi" \
  --category "AudioVideo" \
  --icon "$ICON_DIR/crunchyroll.png"

python3 "$SCRIPT_DIR/create_webapp.py" \
  --name "Disney+" \
  --url "https://www.disneyplus.com/en-it" \
  --desc "Disney+ streaming platform" \
  --browser "Vivaldi" \
  --category "AudioVideo" \
  --icon "$ICON_DIR/disneyplus.png"

python3 "$SCRIPT_DIR/create_webapp.py" \
  --name "Gemini" \
  --url "https://gemini.google.com/" \
  --desc "Google AI assistant" \
  --browser "Vivaldi" \
  --category "Utility" \
  --icon "$ICON_DIR/gemini.png"

python3 "$SCRIPT_DIR/create_webapp.py" \
  --name "Homebrewery" \
  --url "https://homebrewery.naturalcrit.com/" \
  --desc "D&D homebrew editor" \
  --browser "Vivaldi" \
  --category "Office" \
  --icon "$ICON_DIR/homebrewery.png"

python3 "$SCRIPT_DIR/create_webapp.py" \
  --name "Inkarnate" \
  --url "https://inkarnate.com/" \
  --desc "Fantasy map creation tool" \
  --browser "Vivaldi" \
  --category "Graphics" \
  --icon "$ICON_DIR/inkarnate.png"

python3 "$SCRIPT_DIR/create_webapp.py" \
  --name "Microsoft Outlook" \
  --url "https://outlook.office.com/mail/" \
  --desc "Microsoft Outlook web mail" \
  --browser "Vivaldi" \
  --category "Office" \
  --icon "$ICON_DIR/outlook.png"

python3 "$SCRIPT_DIR/create_webapp.py" \
  --name "Microsoft Teams" \
  --url "https://teams.microsoft.com/" \
  --desc "Microsoft Teams collaboration" \
  --browser "Vivaldi" \
  --category "Office" \
  --icon "$ICON_DIR/teams.png"

python3 "$SCRIPT_DIR/create_webapp.py" \
  --name "Netflix" \
  --url "https://www.netflix.com/" \
  --desc "Netflix streaming platform" \
  --browser "Vivaldi" \
  --category "AudioVideo" \
  --icon "$ICON_DIR/netflix.png"

python3 "$SCRIPT_DIR/create_webapp.py" \
  --name "NotebookLM" \
  --url "https://notebooklm.google.com/" \
  --desc "Google AI research notebook" \
  --browser "Vivaldi" \
  --category "Education" \
  --icon "$ICON_DIR/notebooklm.png"

python3 "$SCRIPT_DIR/create_webapp.py" \
  --name "Whatsapp" \
  --url "https://web.whatsapp.com/" \
  --desc "WhatsApp Web messaging" \
  --browser "Vivaldi" \
  --category "Network" \
  --icon "$ICON_DIR/whatsapp.png"
