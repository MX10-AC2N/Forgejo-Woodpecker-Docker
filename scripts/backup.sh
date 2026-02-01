#!/bin/bash
set -euo pipefail

BACKUP_DIR="/backups"
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="$BACKUP_DIR/forgejo-dump-$DATE.zip"
LOG_FILE="/data/log/forgejo-backup.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"; }

log "Début sauvegarde complète Forgejo..."

mkdir -p "$BACKUP_DIR"

# Méthode recommandée : forgejo dump
if command -v forgejo >/dev/null 2>&1; then
    log "Utilisation de 'forgejo dump' (méthode officielle)"
    
    # Forgejo 14 : syntaxe sans --target, dump direct dans le répertoire courant
    cd "$BACKUP_DIR" || exit 1
    
    # Exécuter le dump (crée un fichier forgejo-dump-*.zip)
    if forgejo dump --file "forgejo-dump-$DATE" --type zip --tempdir /tmp 2>&1 | tee -a "$LOG_FILE"; then
        log "✅ Dump créé avec succès"
        
        # Renommer si nécessaire pour avoir un nom cohérent
        CREATED_FILE=$(find "$BACKUP_DIR" -name "forgejo-dump-*.zip" -type f -mmin -2 | head -n1)
        
        if [ -n "$CREATED_FILE" ] && [ "$CREATED_FILE" != "$BACKUP_FILE" ]; then
            mv "$CREATED_FILE" "$BACKUP_FILE" 2>/dev/null || BACKUP_FILE="$CREATED_FILE"
        fi
    else
        log "⚠️ Échec forgejo dump, fallback tar"
        tar -czf "$BACKUP_FILE" -C /data --exclude='log/*' --exclude='*.lock' .
    fi
else
    log "⚠️ forgejo non trouvé → fallback tar /data (moins sûr)"
    tar -czf "$BACKUP_FILE" -C /data --exclude='log/*' --exclude='*.lock' .
fi

if [ -f "$BACKUP_FILE" ]; then
    SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    log "✅ Sauvegarde créée : $(basename "$BACKUP_FILE") ($SIZE)"

    # Garder seulement les 7 dernières
    find "$BACKUP_DIR" -name "forgejo-dump-*.zip" -type f | sort -r | tail -n +8 | xargs -r rm
    log "🧹 Anciennes sauvegardes supprimées (rétention 7)"
else
    log "❌ Échec création sauvegarde"
    exit 1
fi

log "Sauvegarde terminée"