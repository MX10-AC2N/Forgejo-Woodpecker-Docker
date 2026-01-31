#!/bin/bash
set -e


# Démarrer cron en arrière-plan
crond

# Attendre un peu pour que cron soit bien lancé
sleep 2

# Lancer Forgejo
exec /usr/sbin/forgejo "$@"