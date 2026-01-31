#!/bin/bash
set -e

# Démarrer cron en arrière-plan
crond

# Lancer Forgejo (chemin correct)
exec /usr/local/bin/forgejo "$@"
