#!/bin/bash
set -e

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Configuration des permissions..." >> /data/log/forgejo-init.log

# Créer les répertoires nécessaires avec les bonnes permissions
mkdir -p /data/git
mkdir -p /data/git/repositories
mkdir -p /data/log

# Donner les permissions à l'utilisateur git
chown -R git:git /data

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Permissions configurées" >> /data/log/forgejo-init.log

# Démarrer cron en arrière-plan
crond

# Lancer Forgejo
exec /usr/local/bin/forgejo "$@"
