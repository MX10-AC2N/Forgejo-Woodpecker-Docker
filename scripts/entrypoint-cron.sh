#!/bin/bash
set -euo pipefail

LOG_FILE="/data/log/forgejo-init.log"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Démarrage entrypoint custom Forgejo" >> "$LOG_FILE"

# Permissions sur volumes
mkdir -p /data/git/repositories /data/log
chown -R git:git /data

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Permissions appliquées" >> "$LOG_FILE"

# Lancement cron en foreground sous git (utilise busybox crond si dcron absent)
# Busybox crond est souvent présent dans Alpine base ; -f pour foreground, -L pour logs
if command -v crond >/dev/null; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Lancement crond sous git..." >> "$LOG_FILE"
    gosu git crond -f -L /dev/stdout &
elif command -v /usr/sbin/crond >/dev/null; then
    gosu git /usr/sbin/crond -f -L /dev/stdout &
else
    echo "ERREUR : crond non trouvé – installe dcron ou busybox-cron dans Dockerfile" >> "$LOG_FILE"
    # Ne pas exit 1 pour ne pas bloquer, mais cron ne tournera pas
fi

# Appel entrypoint officiel (chemin standard Forgejo Docker rootless/standard)
OFFICIAL_ENTRYPOINT="/usr/local/bin/docker-entrypoint.sh"

if [ -x "$OFFICIAL_ENTRYPOINT" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Exécution entrypoint officiel..." >> "$LOG_FILE"
    exec gosu git "\( OFFICIAL_ENTRYPOINT" " \)@"
else
    # Fallback binaire direct (chemin courant en v14+)
    echo "Fallback : lancement direct forgejo" >> "$LOG_FILE"
    exec gosu git /usr/local/bin/forgejo "$@"
fi