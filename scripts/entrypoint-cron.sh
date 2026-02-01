#!/bin/bash
set -euo pipefail

LOG_FILE="/data/log/forgejo-init.log"
mkdir -p /data/log
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Démarrage entrypoint custom Forgejo" >> "$LOG_FILE"

# Permissions sur volumes (optimisé pour ne pas parcourir tout l'arbre à chaque fois)
mkdir -p /data/git/repositories /data/log /backups
chown git:git /data /data/git /data/log /backups 2>/dev/null || true

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Permissions appliquées" >> "$LOG_FILE"

# Exécuter l'initialisation une seule fois
if [ ! -f /data/.initialized ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Premier démarrage → exécution first-run-init.sh" >> "$LOG_FILE"
  /scripts/first-run-init.sh >> "$LOG_FILE" 2>&1 || echo "⚠️ Initialisation échouée (peut-être déjà fait)" >> "$LOG_FILE"
  touch /data/.initialized
else
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Forgejo déjà initialisé" >> "$LOG_FILE"
fi

# Lancement cron avec su (remplace gosu)
if command -v crond >/dev/null 2>&1; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Lancement crond sous user git avec su..." >> "$LOG_FILE"
    su - git -c "crond -f -L /dev/stdout" &
elif command -v /usr/sbin/crond >/dev/null 2>&1; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Lancement crond (via /usr/sbin) sous user git..." >> "$LOG_FILE"
    su - git -c "/usr/sbin/crond -f -L /dev/stdout" &
else
    echo "AVERTISSEMENT : crond non trouvé – les jobs cron ne tourneront pas" >> "$LOG_FILE"
fi

# Entrypoint officiel Forgejo (chemin standard dans images Docker)
OFFICIAL_ENTRYPOINT="/usr/local/bin/docker-entrypoint.sh"

if [ -x "$OFFICIAL_ENTRYPOINT" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Lancement entrypoint officiel Forgejo..." >> "$LOG_FILE"
    # Exécute en tant que git avec exec pour remplacer le PID 1
    # Fix: passage correct des arguments avec exec
    exec su-exec git "$OFFICIAL_ENTRYPOINT" "$@"
else
    # Fallback : lancement direct du binaire forgejo en tant que git
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Fallback : lancement direct forgejo sous git" >> "$LOG_FILE"
    exec su-exec git /usr/local/bin/forgejo "$@"
fi