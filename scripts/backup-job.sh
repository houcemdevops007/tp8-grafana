#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# TP8 — étape 6 : simule une tâche de sauvegarde qui POUSSE ses résultats
# vers la Pushgateway.
#
# Pourquoi pousser ? Ce script vit 4 secondes. Prometheus, qui scrape toutes
# les 15 secondes, ne le verrait jamais. Un job batch n'a pas d'adresse
# stable à interroger : il doit déposer son résultat quelque part.
#
#   ./scripts/backup-job.sh            # sauvegarde qui réussit
#   ./scripts/backup-job.sh --fail     # sauvegarde qui échoue
# ---------------------------------------------------------------------------
set -euo pipefail

PUSHGATEWAY="${PUSHGATEWAY:-http://localhost:9091}"
JOB="sauvegarde"
INSTANCE="${INSTANCE:-$(hostname -s)}"
FAIL=0
[[ "${1:-}" == "--fail" ]] && FAIL=1

echo "→ Sauvegarde simulée (job=$JOB, instance=$INSTANCE)…"
START=$(date +%s)
sleep 4                                  # « travail » de la sauvegarde
END=$(date +%s)
DURATION=$(( END - START ))
SIZE=$(( RANDOM * 2000 + 150000000 ))    # ~150 Mo, pour avoir une courbe
FILES=$(( RANDOM % 500 + 1200 ))

# L'URL porte les labels : /metrics/job/<job>/<label>/<valeur>/...
# Ce sont EUX que honor_labels: true préserve côté Prometheus.
URL="$PUSHGATEWAY/metrics/job/$JOB/instance/$INSTANCE"

if [[ $FAIL -eq 1 ]]; then
  echo "→ Échec simulé : on pousse le résultat SANS toucher à l'horodatage de succès."
  # Le piège à comprendre : on ne remet PAS à jour
  # backup_last_success_timestamp_seconds. C'est ce qui fera vieillir la
  # métrique et déclenchera l'alerte BackupTooOld.
  cat <<EOF | curl -sS --data-binary @- "$URL"
# HELP backup_duration_seconds Durée de la dernière sauvegarde.
# TYPE backup_duration_seconds gauge
backup_duration_seconds $DURATION
# HELP backup_last_exit_code Code de sortie de la dernière sauvegarde.
# TYPE backup_last_exit_code gauge
backup_last_exit_code 1
EOF
  echo "✗ Sauvegarde en échec poussée vers $URL"
  exit 0
fi

cat <<EOF | curl -sS --data-binary @- "$URL"
# HELP backup_last_success_timestamp_seconds Horodatage Unix de la dernière sauvegarde réussie.
# TYPE backup_last_success_timestamp_seconds gauge
backup_last_success_timestamp_seconds $END
# HELP backup_duration_seconds Durée de la dernière sauvegarde.
# TYPE backup_duration_seconds gauge
backup_duration_seconds $DURATION
# HELP backup_size_bytes Taille de l'archive produite.
# TYPE backup_size_bytes gauge
backup_size_bytes $SIZE
# HELP backup_files_total Nombre de fichiers sauvegardés.
# TYPE backup_files_total gauge
backup_files_total $FILES
# HELP backup_last_exit_code Code de sortie de la dernière sauvegarde.
# TYPE backup_last_exit_code gauge
backup_last_exit_code 0
EOF

echo "✓ Poussé vers $URL  (durée ${DURATION}s, $(( SIZE / 1024 / 1024 )) Mo, $FILES fichiers)"
echo "  Vérifie :  curl -s $PUSHGATEWAY/metrics | grep backup_"
