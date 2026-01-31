#!/bin/bash
# Script d'optimisation automatique de SQLite pour Forgejo

set -e

echo "========================================"
echo "🔧 Maintenance automatique Forgejo - $(date)"
echo "========================================"

# Configuration
CHEMIN_DB="/data/forgejo.db"
BACKUP_DIR="/backups"
RETENTION_JOURS=30
LOG_FILE="/data/forgejo-maintenance.log"

# Fonction de logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# 1. Créer le dossier de sauvegardes si inexistant
mkdir -p "$BACKUP_DIR"
log "Dossier de sauvegarde prêt: $BACKUP_DIR"

# 2. Sauvegarde sécurisée avec .backup
log "Début de la sauvegarde..."
BACKUP_FILE="$BACKUP_DIR/forgejo-backup-$(date +%Y%m%d-%H%M%S).db"
if sqlite3 "$CHEMIN_DB" ".backup '$BACKUP_FILE.tmp'"; then
    mv "$BACKUP_FILE.tmp" "$BACKUP_FILE"
    BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    log "✅ Sauvegarde créée: $(basename $BACKUP_FILE) ($BACKUP_SIZE)"
else
    log "❌ Échec de la sauvegarde!"
    exit 1
fi

# 3. Optimisation SQLite
log "Optimisation de la base de données..."
sqlite3 "$CHEMIN_DB" "VACUUM;" && log "  • VACUUM terminé"
sqlite3 "$CHEMIN_DB" "PRAGMA optimize;" && log "  • PRAGMA optimize terminé"
sqlite3 "$CHEMIN_DB" "ANALYZE;" && log "  • ANALYZE terminé"

# 4. Vérification d'intégrité
log "Vérification d'intégrité..."
INTEGRITE=$(sqlite3 "$CHEMIN_DB" "PRAGMA integrity_check;")
if [ "$INTEGRITE" = "ok" ]; then
    log "✅ Base de données intègre"
else
    log "⚠️  Problème détecté: $INTEGRITE"
fi

# 5. Nettoyage des anciennes sauvegardes
log "Nettoyage des anciennes sauvegardes..."
find "$BACKUP_DIR" -name "forgejo-backup-*.db" -type f -mtime +$RETENTION_JOURS -delete
NB_SUPPRIMEES=$(find "$BACKUP_DIR" -name "forgejo-backup-*.db" -type f -mtime +$RETENTION_JOURS | wc -l)
log "✅ $NB_SUPPRIMEES sauvegarde(s) de plus de $RETENTION_JOURS jours supprimée(s)"

# 6. Rapport succinct
TAILLE_DB=$(sqlite3 "$CHEMIN_DB" "SELECT page_count * page_size / 1024 / 1024 as size_mb FROM pragma_page_count(), pragma_page_size();")
NB_REPOS=$(sqlite3 "$CHEMIN_DB" "SELECT COUNT(*) FROM repository;")

log "📊 Rapport final:"
log "  • Taille DB: ${TAILLE_DB} MB"
log "  • Dépôts: $NB_REPOS"
log "  • Prochaine maintenance: dimanche 3h"

echo "========================================"
log "✅ Maintenance terminée avec succès!"
echo "========================================"