#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# TP8 — étape 11 : génère du trafic sur l'application Java instrumentée.
#
#   ./scripts/load-app.sh              # 120 s, dont quelques requêtes lentes
#   ./scripts/load-app.sh 300 --slow   # une requête sur deux est lente
#
# Chaque requête produit une TRACE : HTTP -> application -> PostgreSQL.
# ---------------------------------------------------------------------------
set -euo pipefail

DURATION="${1:-120}"
MODE="${2:-}"
PORT="${APP_PORT:-8081}"
BASE="http://localhost:$PORT"

[[ "$DURATION" =~ ^[0-9]+$ ]] || { echo "Durée invalide : $DURATION" >&2; exit 1; }

if ! curl -sf -o /dev/null "$BASE/healthz"; then
  echo "✗ $BASE ne répond pas." >&2
  echo "  Le profil traces est-il démarré ? docker compose --profile traces ps" >&2
  exit 1
fi

echo "→ Trafic sur $BASE pendant ${DURATION}s"
END=$(( $(date +%s) + DURATION ))
N=0

while [[ $(date +%s) -lt $END ]]; do
  curl -sf -o /dev/null "$BASE/produits"           || true
  curl -sf -o /dev/null "$BASE/produits/1"         || true
  N=$(( N + 2 ))

  # Requêtes lentes : l'application exécute un pg_sleep côté PostgreSQL.
  # C'est ce span-là que tu devras retrouver dans Tempo.
  if [[ "$MODE" == "--slow" ]] || (( N % 10 == 0 )); then
    curl -sf -o /dev/null "$BASE/produits?lent=1" || true
    N=$(( N + 1 ))
  fi
  sleep 0.3
done

echo "✓ $N requêtes envoyées."
echo "  Dans Grafana › Explore › Tempo :  { duration > 500ms }"
