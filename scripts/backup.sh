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
    
    # Créer le dump dans un répertoire temporaire
    TEMP_DUMP_DIR=$(mktemp -d)
    forgejo dump --target "$TEMP_DUMP_DIR" --archive-format tar.gz --temp-dir /tmp
    
    # Trouver et renommer le fichier créé
    CREATED_FILE=$(find "$TEMP_DUMP_DIR" -name "forgejo-dump-*.tar.gz" -o -name "forgejo-dump-*.zip" | head -n1)
    
    if [ -n "$CREATED_FILE" ]; then
        # Si c'est un zip, on le laisse tel quel, sinon on utilise .tar.gz
        if [[ "$CREATED_FILE" == *.zip ]]; then
            BACKUP_FILE="${BACKUP_FILE%.tar.gz}.zip"
        fi
        mv "$CREATED_FILE" "$BACKUP_FILE"
        rm -rf "$TEMP_DUMP_DIR"
    else
        log "⚠️ Aucun fichier dump créé, fallback sur tar"
        rm -rf "$TEMP_DUMP_DIR"
        tar -czf "$BACKUP_FILE" -C /data --exclude='log/*' --exclude='*.lock' .
    fi
else
    log "⚠️ forgejo non trouvé → fallback tar /data (moins sûr)"
    tar -czf "$BACKUP_FILE" -C /data --exclude='log/*' --exclude='*.lock' .
fi

if [ -f "$BACKUP_FILE" ]; then
    SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    log "✅ Sauvegarde créée : $(basename "$BACKUP_FILE") ($SIZE)"

    # Garder seulement les 7 dernières (tar.gz et zip)
    find "$BACKUP_DIR" \( -name "forgejo-dump-*.tar.gz" -o -name "forgejo-dump-*.zip" \) -type f | sort -r | tail -n +8 | xargs -r rm
    log "🧹 Anciennes sauvegardes supprimées (rétention 7)"
else
    log "❌ Échec création sauvegarde"
    exit 1
fi

log "Sauvegarde terminée"