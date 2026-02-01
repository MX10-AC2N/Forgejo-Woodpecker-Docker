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

# Vérifier que la DB existe
if [ ! -f "$CHEMIN_DB" ]; then
    log "⚠️ Base de données non trouvée : $CHEMIN_DB"
    exit 1
fi

# Hot backup
log "Sauvegarde hot (.backup)..."
BACKUP_FILE="$BACKUP_DIR/forgejo-$(date +%Y%m%d-%H%M%S).db"
BACKUP_TEMP="${BACKUP_FILE}.tmp"

# Utiliser sqlite3 pour un backup à chaud
if sqlite3 "$CHEMIN_DB" ".backup '$BACKUP_TEMP'" 2>/dev/null; then
    mv "$BACKUP_TEMP" "$BACKUP_FILE"
    BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    log "✅ Backup créé : $(basename "$BACKUP_FILE") ($BACKUP_SIZE)"
else
    log "❌ Échec du backup, abandon de la maintenance"
    rm -f "$BACKUP_TEMP"
    exit 1
fi

# Optimisations
log "Optimisation SQLite..."
if sqlite3 "$CHEMIN_DB" "VACUUM;" 2>/dev/null; then
    log "  • VACUUM OK"
else
    log "  ⚠️ VACUUM échec"
fi

if sqlite3 "$CHEMIN_DB" "PRAGMA optimize;" 2>/dev/null; then
    log "  • PRAGMA optimize OK"
else
    log "  ⚠️ PRAGMA optimize échec"
fi

if sqlite3 "$CHEMIN_DB" "ANALYZE;" 2>/dev/null; then
    log "  • ANALYZE OK"
else
    log "  ⚠️ ANALYZE échec"
fi

# Intégrité
log "Vérification intégrité..."
INTEGRITY=$(sqlite3 "$CHEMIN_DB" "PRAGMA integrity_check(1);" 2>/dev/null || echo "error")
if [[ "$INTEGRITY" == "ok" ]]; then
    log "✅ Intégrité OK"
else
    log "⚠️ Problème d'intégrité : $INTEGRITY"
fi

# Nettoyage des anciens backups
log "Suppression anciennes backups (> $RETENTION_DAYS jours)..."
DELETED_COUNT=$(find "$BACKUP_DIR" -type f -name "forgejo-*.db" -mtime +$RETENTION_DAYS -delete -print | wc -l)
log "🗑️ $DELETED_COUNT ancien(s) backup(s) supprimé(s)"

# Rapport final
SIZE_MB=$(du -m "$CHEMIN_DB" | cut -f1)
NB_REPOS=$(sqlite3 "$CHEMIN_DB" "SELECT COUNT(*) FROM repository;" 2>/dev/null || echo "?")
log "📊 Taille DB : ${SIZE_MB} MB   |   Dépôts : $NB_REPOS"
log "✅ Maintenance terminée"
log "========================================"