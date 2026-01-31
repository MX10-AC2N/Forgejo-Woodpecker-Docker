#!/bin/bash
set -e

# Démarrer cron en arrière-plan (root)
crond -b -c /etc/crontabs

# Attendre un peu pour que cron soit bien lancé
sleep 2

# Démarrer Forgejo avec l'utilisateur de l'image officielle
# L'image Forgejo utilise déjà l'utilisateur approprié
exec su-exec $(id -u):$(id -g) /usr/local/bin/forgejo web