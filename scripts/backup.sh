#!/bin/bash
set -euo pipefail

BACKUP_DIR="/backups"
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="$BACKUP_DIR/forgejo-dump-$DATE.tar.gz"
LOG_FILE="/data/log/forgejo-backup.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"; }

log "Début sauvegarde complète Forgejo..."

mkdir -p "$BACKUP_DIR"

# Méthode recommandée : forgejo dump
if command -v forgejo >/dev/null 2>&1; then
    log "Utilisation de 'forgejo dump' (méthode officielle)"
    forgejo dump --target "$BACKUP_DIR" --archive-format tar.gz --temp-dir /tmp
    # Le fichier créé est généralement forgejo-dump-<date>.zip ou .tar.gz
    # On le renomme pour cohérence
    mv "$BACKUP_DIR"/forgejo-dump-*.tar.gz "$BACKUP_FILE" 2>/dev/null || mv "\( BACKUP_DIR"/forgejo-dump-*.zip " \){BACKUP_FILE%.gz}.zip"
else
    log "⚠️ forgejo non trouvé → fallback tar /data (moins sûr)"
    tar -czf "$BACKUP_FILE" -C /data --exclude='log/*' --exclude='*.lock' .
fi

if [ -f "$BACKUP_FILE" ]; then
    SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    log "✅ Sauvegarde créée : $(basename "$BACKUP_FILE") ($SIZE)"

    # Garder seulement les 7 dernières
    find "$BACKUP_DIR" -name "forgejo-dump-*.tar.gz" -type f | sort -r | tail -n +8 | xargs -r rm
    log "🧹 Anciennes sauvegardes supprimées (rétention 7)"
else
    log "❌ Échec création sauvegarde"
    exit 1
fi

log "Sauvegarde terminée"