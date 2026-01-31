#!/bin/bash
set -euo pipefail

LOG_FILE="/data/log/forgejo-init.log"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Démarrage entrypoint custom..." >> "$LOG_FILE"

# Créer et chown les répertoires critiques (si volume monté vide)
mkdir -p /data/git/repositories /data/log
chown -R git:git /data

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Permissions configurées" >> "$LOG_FILE"

# Lancer cron en foreground sous git (dcron ou busybox crond)
# On redirige les logs cron vers stdout pour docker logs
if command -v crond >/dev/null; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Lancement de crond (sous git)..." >> "$LOG_FILE"
    gosu git crond -f -L /dev/stdout &
else
    echo "ERREUR : crond non trouvé" >> "$LOG_FILE"
    exit 1
fi

# Optionnel : attendre que Forgejo soit "prêt" avant cron jobs (si tes scripts en ont besoin)
# sleep 10  # ou une boucle until curl http://localhost:3000/api/healthz

# Exécuter l'entrypoint OFFICIEL Forgejo (le plus important !)
# Chemin probable dans image Forgejo 14+ ; ajuste si nécessaire après test
OFFICIAL_ENTRYPOINT="/usr/local/bin/docker-entrypoint.sh"   # ou /app/gitea/docker/entrypoint.sh, etc.

if [ -x "$OFFICIAL_ENTRYPOINT" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Exécution de l'entrypoint officiel Forgejo..." >> "$LOG_FILE"
    exec gosu git "\( OFFICIAL_ENTRYPOINT" " \)@"
else
    echo "ERREUR : entrypoint officiel non trouvé ($OFFICIAL_ENTRYPOINT)" >> "$LOG_FILE"
    # Fallback : lancer directement le binaire (moins bien, mais mieux que rien)
    echo "Fallback : lancement direct de forgejo" >> "$LOG_FILE"
    exec gosu git /usr/local/bin/forgejo "$@"
fi