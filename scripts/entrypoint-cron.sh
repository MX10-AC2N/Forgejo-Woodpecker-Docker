#!/bin/bash
# Point d'entrée qui lance Forgejo ET cron

set -e

# Démarrer cron en arrière-plan (avec l'utilisateur forgejo)
crond -b -c /etc/crontabs -l 8

# Attendre un peu pour que cron soit bien lancé
sleep 2

# Démarrer Forgejo (commande originale)
exec su-exec forgejo:forgejo /usr/local/bin/forgejo web