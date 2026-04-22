#!/bin/bash

# Imposto il percorso al file di configurazione
CONFIG="$HOME/.config/hypr/conf/keybindings.conf"

# Prelevo il valore reale di $mainMod dal file (es. SUPER)
mainMod=$(grep -oP '^\s*\$mainMod\s*=\s*\K\S+' "$CONFIG")

# Creo un array vuoto per accumulare le voci di menu
menu_entries=()

# Scorro ogni riga del file di configurazione
while IFS= read -r line; do
  # Skip delle righe vuote o solo commento
  [[ -z "$line" || "$line" =~ ^\s*# ]] && continue

  # Se la riga comincia per bind, bindm o binde
  if [[ "$line" =~ ^\s*bind ]]; then
    # Estraggo la parte prima del # (la keybind vera e propria)
    entry_raw="${line%%#*}"
    # Rimuovo il prefisso bind =, bindm = o binde =
    entry_raw="${entry_raw#*bind*=}"
    # Normalizzo gli spazi ai lati
    entry_raw="$(echo "$entry_raw" | xargs)"
    # Sostituisco la variabile $mainMod col suo valore
    entry_keys="${entry_raw//\$mainMod/$mainMod}"

    # Estraggo la descrizione dopo il simbolo #
    desc_raw="${line#*#}"
    # Normalizzo spazi a inizio/fine
    desc="$(echo "$desc_raw" | xargs)"

    # Aggiungo al menu la stringa "COMBINAZIONE : DESCRIZIONE"
    menu_entries+=("$entry_keys : $desc")
  fi
done < "$CONFIG"

# Lancio rofi in modalità dmenu con la lista di keybindings
printf '%s\n' "${menu_entries[@]}" | rofi -dmenu -i -p "Hyprland Keybindings"


