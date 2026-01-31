#!/bin/bash
set -e

BACKUP_DIR="/backups"
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="$BACKUP_DIR/forgejo-backup-$DATE.tar.gz"
LOG_FILE="/data/log/forgejo-backup.log"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Début de la sauvegarde..." >> "$LOG_FILE"

# Créer le répertoire de sauvegarde
mkdir -p "$BACKUP_DIR"

# Sauvegarder les données essentielles
tar -czf "$BACKUP_FILE" \
    -C /data \
    --exclude='log/*' \
    .

# Vérifier le succès
if [ -f "$BACKUP_FILE" ]; then
    SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Sauvegarde créée : forgejo-backup-$DATE.tar.gz ($SIZE)" >> "$LOG_FILE"
    
    # Garder uniquement les 7 dernières sauvegardes
    ls -t "$BACKUP_DIR"/forgejo-backup-*.tar.gz 2>/dev/null | tail -n +8 | xargs -r rm
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🧹 Sauvegardes anciennes (>7 jours) supprimées" >> "$LOG_FILE"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ ÉCHEC de la sauvegarde" >> "$LOG_FILE"
    exit 1
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Sauvegarde terminée" >> "$LOG_FILE"
