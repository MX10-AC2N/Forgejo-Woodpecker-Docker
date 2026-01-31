#!/bin/bash
set -euo pipefail

LOG_FILE="/data/log/forgejo-init.log"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Démarrage entrypoint custom Forgejo" >> "$LOG_FILE"

# Permissions
mkdir -p /data/git/repositories /data/log
chown -R git:git /data

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Permissions appliquées" >> "$LOG_FILE"

# Lancement crond (BusyBox version, souvent /usr/sbin/crond ou /bin/crond)
CROND_BIN=$(command -v crond || command -v /usr/sbin/crond || command -v /bin/crond)
if [ -n "$CROND_BIN" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Lancement crond (BusyBox) sous git..." >> "$LOG_FILE"
    gosu git "$CROND_BIN" -f -L /dev/stdout &
else
    echo "AVERTISSEMENT : crond non trouvé – cron ne tournera pas" >> "$LOG_FILE"
    # Ne pas exit pour ne pas bloquer Forgejo
fi

# Entrypoint officiel Forgejo (chemin confirmé pour images rootless)
OFFICIAL_ENTRYPOINT="/usr/local/bin/docker-entrypoint.sh"

if [ -x "$OFFICIAL_ENTRYPOINT" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Exécution entrypoint officiel..." >> "$LOG_FILE"
    exec gosu git "\( OFFICIAL_ENTRYPOINT" " \)@"
else
    # Fallback binaire (chemin standard Forgejo v14+)
    echo "Fallback : lancement direct /usr/local/bin/forgejo" >> "$LOG_FILE"
    exec gosu git /usr/local/bin/forgejo "$@"
fi