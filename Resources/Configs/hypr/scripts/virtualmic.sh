#!/usr/bin/env bash
set -euo pipefail

# ============================================================
#  VirtualMic per PipeWire (Arch / PulseAudio compat layer)
#  Mixa: audio di sistema + microfono reale -> microfono virtuale
#
#  Comandi:
#    ./virtualmic.sh start
#    ./virtualmic.sh stop
#    ./virtualmic.sh status
#
#  Variabili opzionali:
#    REAL_SINK  = sink reale (casse/cuffie)
#    REAL_MIC   = sorgente reale (il tuo mic)
#  Se non le setti, usa i default di PulseAudio/PipeWire.
# ============================================================

STATE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/virtualmic.state"
mkdir -p "$(dirname "$STATE_FILE")"

MIX_SINK_NAME="MixForVirtualMic"
COMBINE_SINK_NAME="VirtualMicOut"

# Prende i default attuali di PipeWire/PulseAudio
DEFAULT_SINK="$(pactl get-default-sink)"
DEFAULT_SOURCE="$(pactl get-default-source)"

REAL_SINK="${REAL_SINK:-$DEFAULT_SINK}"
REAL_MIC="${REAL_MIC:-$DEFAULT_SOURCE}"

usage() {
  cat <<EOF
Usage: $0 {start|stop|status}

Opzionalmente:
  REAL_SINK=<nome_sink> REAL_MIC=<nome_source> $0 start

Per vedere i nomi:
  pactl list short sinks
  pactl list short sources
EOF
}

status() {
  if [[ -f "$STATE_FILE" ]]; then
    echo "VirtualMic: ATTIVO"
    cat "$STATE_FILE"
  else
    echo "VirtualMic: non attivo"
  fi
}

start_vm() {
  if [[ -f "$STATE_FILE" ]]; then
    echo "Sembra che VirtualMic sia già attivo (trovato $STATE_FILE)."
    echo "Usa '$0 status' oppure '$0 stop' prima di riavviarlo."
    exit 1
  fi

  echo "Usando sink reale:   $REAL_SINK"
  echo "Usando microfono:    $REAL_MIC"

  # 1) Sink finto per il mix
  MIX_MODULE_ID=$(pactl load-module module-null-sink \
    sink_name="$MIX_SINK_NAME" \
    sink_properties=device.description="$MIX_SINK_NAME")

  # 2) Sink combinato: manda l'audio sia al mix che alle casse
  COMBINE_MODULE_ID=$(pactl load-module module-combine-sink \
    sink_name="$COMBINE_SINK_NAME" \
    slaves="$MIX_SINK_NAME","$REAL_SINK" \
    sink_properties=device.description="$COMBINE_SINK_NAME")

  # 3) Loopback del mic reale nel sink di mix
  LOOP_MODULE_ID=$(pactl load-module module-loopback \
    source="$REAL_MIC" \
    sink="$MIX_SINK_NAME" \
    latency_msec=20)

  # Setta il nuovo sink combinato come default
  pactl set-default-sink "$COMBINE_SINK_NAME"

  # Salva stato: ID moduli + sink default precedente
  {
    echo "MIX_MODULE_ID=$MIX_MODULE_ID"
    echo "COMBINE_MODULE_ID=$COMBINE_MODULE_ID"
    echo "LOOP_MODULE_ID=$LOOP_MODULE_ID"
    echo "OLD_DEFAULT_SINK=$REAL_SINK"
  } >"$STATE_FILE"

  echo "VirtualMic avviato."
  echo "Ora, nelle app, seleziona come microfono: 'Monitor of $MIX_SINK_NAME'"
}

stop_vm() {
  if [[ ! -f "$STATE_FILE" ]]; then
    echo "VirtualMic non risulta attivo (manca $STATE_FILE)."
    exit 0
  fi

  # shellcheck disable=SC1090
  source "$STATE_FILE"

  # Ripristina default sink
  if [[ -n "${OLD_DEFAULT_SINK:-}" ]]; then
    pactl set-default-sink "$OLD_DEFAULT_SINK" || true
  fi

  # Unload moduli in ordine inverso
  for id_var in LOOP_MODULE_ID COMBINE_MODULE_ID MIX_MODULE_ID; do
    id="${!id_var:-}"
    if [[ -n "$id" ]]; then
      pactl unload-module "$id" || true
    fi
  done

  rm -f "$STATE_FILE"
  echo "VirtualMic fermato e configurazione ripristinata."
}

case "${1:-}" in
start) start_vm ;;
stop) stop_vm ;;
status) status ;;
*)
  usage
  exit 1
  ;;
esac
