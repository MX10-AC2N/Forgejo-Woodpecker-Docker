#!/bin/bash
set -euo pipefail

LOG_FILE="/data/log/forgejo-init.log"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Démarrage entrypoint custom Forgejo" >> "$LOG_FILE"

# Permissions sur volumes (au cas où bind mount change ownership)
mkdir -p /data/git/repositories /data/log
chown -R git:git /data

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Permissions appliquées" >> "$LOG_FILE"

# Cron avec BusyBox crond (présent dans /usr/sbin/crond ou /bin/crond)
CROND_PATH=$(command -v crond || command -v /usr/sbin/crond || echo "")
if [ -n "$CROND_PATH" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Lancement crond BusyBox sous git..." >> "$LOG_FILE"
    gosu git "$CROND_PATH" -f -L /dev/stdout &
else
    echo "AVERTISSEMENT : crond non trouvé dans l'image – jobs cron ne tourneront pas" >> "$LOG_FILE"
fi

# Entrypoint OFFICIEL Forgejo rootless (confirmé dans sources et docs)
OFFICIAL_ENTRYPOINT="/usr/local/bin/docker-entrypoint.sh"

if [ -x "$OFFICIAL_ENTRYPOINT" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Lancement entrypoint officiel Forgejo..." >> "$LOG_FILE"
    exec gosu git "\( OFFICIAL_ENTRYPOINT" " \)@"
else
    # Fallback direct (binaire forgejo)
    echo "Fallback : lancement /usr/local/bin/forgejo" >> "$LOG_FILE"
    exec gosu git /usr/local/bin/forgejo "$@"
fi