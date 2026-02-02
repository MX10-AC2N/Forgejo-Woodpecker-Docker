#!/bin/bash
set -euo pipefail

LOG_FILE="/data/log/forgejo-init.log"
mkdir -p /data/log
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Démarrage entrypoint custom Forgejo" >> "$LOG_FILE"

# Permissions sur volumes (optimisé pour ne pas parcourir tout l'arbre à chaque fois)
mkdir -p /data/git/repositories /data/log /backups /shared
chown git:git /data /data/git /data/log /backups 2>/dev/null || true
chmod 777 /shared 2>/dev/null || true  # Partagé avec Woodpecker

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Permissions appliquées" >> "$LOG_FILE"

# Exécuter l'initialisation une seule fois
if [ ! -f /data/.initialized ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Premier démarrage → exécution first-run-init.sh" >> "$LOG_FILE"
  
  # Lancer l'init en background APRÈS que Forgejo soit prêt
  (
    sleep 10  # Attendre que Forgejo démarre
    /scripts/first-run-init.sh >> "$LOG_FILE" 2>&1 || echo "⚠️ Initialisation échouée" >> "$LOG_FILE"
  ) &
  
  touch /data/.initialized
else
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Forgejo déjà initialisé" >> "$LOG_FILE"
fi

# Lancement cron EN BACKGROUND (ne pas bloquer le démarrage)
if command -v crond >/dev/null 2>&1; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Lancement crond en background..." >> "$LOG_FILE"
    crond -b -L /data/log/cron.log 2>/dev/null || echo "⚠️ crond non démarré" >> "$LOG_FILE"
elif command -v /usr/sbin/crond >/dev/null 2>&1; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Lancement crond (via /usr/sbin) en background..." >> "$LOG_FILE"
    /usr/sbin/crond -b -L /data/log/cron.log 2>/dev/null || echo "⚠️ crond non démarré" >> "$LOG_FILE"
else
    echo "AVERTISSEMENT : crond non trouvé – les jobs cron ne tourneront pas" >> "$LOG_FILE"
fi

# Entrypoint officiel Forgejo (chemin standard dans images Docker)
OFFICIAL_ENTRYPOINT="/usr/local/bin/docker-entrypoint.sh"

if [ -x "$OFFICIAL_ENTRYPOINT" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Lancement entrypoint officiel Forgejo..." >> "$LOG_FILE"
    # Exécute en tant que git avec exec pour remplacer le PID 1
    exec "$OFFICIAL_ENTRYPOINT" "$@"
else
    # Fallback : lancement direct du binaire forgejo
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Fallback : lancement direct forgejo" >> "$LOG_FILE"
    exec su-exec git /usr/local/bin/forgejo "$@"
fi