#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# TP8 — génère du trafic sur l'Apache de la stack.
#
#   ./scripts/load.sh              # 120 s de trafic normal
#   ./scripts/load.sh 300          # 300 s
#   ./scripts/load.sh 300 --errors # avec 1 requête sur 4 en erreur
#
# Utilise « ab » (apache2-utils) s'il est installé, sinon une boucle curl.
# ---------------------------------------------------------------------------
set -euo pipefail

DURATION="${1:-120}"
MODE="${2:-}"
PORT="${APACHE_PORT:-8080}"
BASE="http://localhost:$PORT"

[[ "$DURATION" =~ ^[0-9]+$ ]] || { echo "Durée invalide : $DURATION" >&2; exit 1; }

if ! curl -sf -o /dev/null "$BASE/"; then
  echo "✗ $BASE ne répond pas. La stack est-elle démarrée ? (docker compose ps)" >&2
  exit 1
fi

echo "→ Trafic sur $BASE pendant ${DURATION}s  (Ctrl-C pour arrêter)"
END=$(( $(date +%s) + DURATION ))
COUNT=0

while [[ $(date +%s) -lt $END ]]; do
  curl -sf -o /dev/null "$BASE/"              || true
  curl -sf -o /dev/null "$BASE/catalogue.html" || true
  if [[ "$MODE" == "--errors" ]]; then
    curl -s -o /dev/null "$BASE/tp/erreur"    || true   # 500
    curl -s -o /dev/null "$BASE/tp/absent"    || true   # 404
  fi
  COUNT=$(( COUNT + 2 ))
  sleep 0.2
done

echo "✓ $COUNT requêtes envoyées."
echo "  Dans Prometheus :  rate(apache_accesses_total[1m])"
