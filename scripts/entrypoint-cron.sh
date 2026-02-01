#!/bin/bash
set -euo pipefail

LOG_FILE="/data/log/forgejo-init.log"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Démarrage entrypoint custom Forgejo" >> "$LOG_FILE"

# Permissions sur volumes
mkdir -p /data/git/repositories /data/log
chown -R git:git /data

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Permissions appliquées" >> "$LOG_FILE"

# Exécuter l’initialisation une seule fois
if [ ! -f /data/.initialized ]; then
  echo "Premier démarrage → exécution first-run-init.sh"
  /scripts/first-run-init.sh
  touch /data/.initialized
else
  echo "Forgejo déjà initialisé"
fi

# Lancement cron avec su (remplace gosu)
if command -v crond >/dev/null 2>&1; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Lancement crond sous user git avec su..." >> "$LOG_FILE"
    su - git -c "crond -f -L /dev/stdout" &
elif command -v /usr/sbin/crond >/dev/null 2>&1; then
    su - git -c "/usr/sbin/crond -f -L /dev/stdout" &
else
    echo "AVERTISSEMENT : crond non trouvé – les jobs cron ne tourneront pas" >> "$LOG_FILE"
fi

# Entrypoint officiel Forgejo (chemin standard dans images Docker)
OFFICIAL_ENTRYPOINT="/usr/local/bin/docker-entrypoint.sh"

if [ -x "$OFFICIAL_ENTRYPOINT" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Lancement entrypoint officiel Forgejo..." >> "$LOG_FILE"
    # Exécute en tant que git avec su (remplace gosu)
    exec su - git -c "$OFFICIAL_ENTRYPOINT $@"
else
    # Fallback : lancement direct du binaire forgejo en tant que git
    echo "Fallback : lancement direct forgejo sous git" >> "$LOG_FILE"
    exec su - git -c "/usr/local/bin/forgejo $@"
fi