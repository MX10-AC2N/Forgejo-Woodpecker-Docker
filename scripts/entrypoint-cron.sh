#!/bin/bash
set -euo pipefail

LOG_FILE="/data/log/forgejo-init.log"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Démarrage entrypoint custom Forgejo" >> "$LOG_FILE"

# Permissions sur les volumes montés
mkdir -p /data/git/repositories /data/log
chown -R git:git /data

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Permissions appliquées" >> "$LOG_FILE"

# Lancement cron en foreground sous git
if command -v crond >/dev/null; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Lancement crond (sous git)..." >> "$LOG_FILE"
    gosu git crond -f -L /dev/stdout &
else
    echo "ERREUR : crond introuvable" >> "$LOG_FILE"
    exit 1
fi

# Appel à l'entrypoint officiel Forgejo (essentiel pour migrations DB, etc.)
OFFICIAL_ENTRYPOINT="/app/gitea/docker/entrypoint.sh"

if [ -x "$OFFICIAL_ENTRYPOINT" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Exécution entrypoint officiel Forgejo..." >> "$LOG_FILE"
    exec gosu git "\( OFFICIAL_ENTRYPOINT" " \)@"
else
    echo "Fallback : entrypoint officiel non trouvé → lancement direct" >> "$LOG_FILE"
    exec gosu git /app/gitea/forgejo "$@"
fi