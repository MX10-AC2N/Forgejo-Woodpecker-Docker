#!/bin/sh
set -e

LOG_FILE="/data/log/forgejo-init.log"
mkdir -p /data/log
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Démarrage entrypoint custom Forgejo" >> "$LOG_FILE"

# Permissions sur volumes
mkdir -p /data/git/repositories /data/log /backups /shared
chown -R git:git /data /backups 2>/dev/null || true
chmod 777 /shared 2>/dev/null || true

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Permissions appliquées" >> "$LOG_FILE"

# Lancer cron en background AVANT de passer en user git
if command -v crond >/dev/null 2>&1; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Lancement crond..." >> "$LOG_FILE"
    crond -b 2>/dev/null || echo "⚠️ crond échec" >> "$LOG_FILE"
fi

# Lancer first-run-init en background (en tant que git)
if [ ! -f /data/.initialized ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Premier démarrage → init en background" >> "$LOG_FILE"
    touch /data/.initialized
    
    # Lancer en background après démarrage de Forgejo
    (
        sleep 15
        su-exec git /scripts/first-run-init.sh >> "$LOG_FILE" 2>&1 || echo "⚠️ Init failed" >> "$LOG_FILE"
    ) &
fi

# Lancer Forgejo en tant que user git (CRUCIAL)
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Lancement Forgejo sous user git..." >> "$LOG_FILE"

# Utiliser su-exec pour passer en user git et lancer l'entrypoint officiel
if [ -x /usr/local/bin/docker-entrypoint.sh ]; then
    exec su-exec git /usr/local/bin/docker-entrypoint.sh "$@"
else
    exec su-exec git /usr/local/bin/forgejo "$@"
fi