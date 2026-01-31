#!/bin/bash
set -euo pipefail

CHEMIN_DB="/data/git/forgejo.db"
BACKUP_DIR="/backups"
RETENTION_DAYS=30
LOG_FILE="/data/log/forgejo-maintenance.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"; }

log "========================================"
log "🔧 Maintenance Forgejo SQLite - $(date)"
log "========================================"

mkdir -p "$BACKUP_DIR"

# Hot backup
log "Sauvegarde hot (.backup)..."
BACKUP_FILE="\( BACKUP_DIR/forgejo- \)(date +%Y%m%d-%H%M%S).db"
sqlite3 "$CHEMIN_DB" ".backup '$BACKUP_FILE.tmp'" && mv "$BACKUP_FILE.tmp" "$BACKUP_FILE"
BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
log "✅ Backup créé : $(basename "$BACKUP_FILE") ($BACKUP_SIZE)"

# Optimisations
log "Optimisation SQLite..."
sqlite3 "$CHEMIN_DB" "VACUUM;"              && log "  • VACUUM OK"
sqlite3 "$CHEMIN_DB" "PRAGMA optimize;"     && log "  • PRAGMA optimize OK"
sqlite3 "$CHEMIN_DB" "ANALYZE;"             && log "  • ANALYZE OK"

# Intégrité
log "Vérification intégrité..."
INTEGRITY=$(sqlite3 "$CHEMIN_DB" "PRAGMA integrity_check(1);")
[[ "$INTEGRITY" == "ok" ]] && log "✅ Intégrité OK" || log "⚠️ Problème : $INTEGRITY"

# Nettoyage
log "Suppression anciennes backups (> $RETENTION_DAYS jours)..."
find "$BACKUP_DIR" -type f -name "forgejo-*.db" -mtime +$RETENTION_DAYS -delete
NB=$(find "$BACKUP_DIR" -type f -name "forgejo-*.db" -mtime +$RETENTION_DAYS | wc -l)
log "🗑️ $NB fichier(s) restant(s) à supprimer (normalement 0)"

# Rapport
SIZE_MB=$(du -m "$CHEMIN_DB" | cut -f1)
NB_REPOS=$(sqlite3 "$CHEMIN_DB" "SELECT COUNT(*) FROM repository;" 2>/dev/null || echo "?")
log "📊 Taille DB : ${SIZE_MB} MB   |   Dépôts : $NB_REPOS"
log "✅ Maintenance terminée"
log "========================================"