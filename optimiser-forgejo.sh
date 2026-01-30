#!/bin/bash
# Script d'optimisation et de sauvegarde pour Forgejo avec SQLite
# À exécuter manuellement ou via cron

echo "========================================"
echo "Maintenance Forgejo - $(date)"
echo "========================================"

# Configuration
NOM_CONTENEUR="forgejo"
CHEMIN_DB="/data/forgejo.db"
BACKUP_DIR="./backups-forgejo"
RETENTION_JOURS=30  # Garder 30 jours de sauvegardes

# 1. Créer le dossier de sauvegardes
mkdir -p "$BACKUP_DIR"

# 2. Sauvegarde de la base SQLite (méthode .backup - sécuritaire)
echo "🔵 Création de la sauvegarde..."
BACKUP_FILE="$BACKUP_DIR/forgejo-backup-$(date +%Y%m%d-%H%M%S).db"
docker exec $NOM_CONTENEUR sqlite3 "$CHEMIN_DB" ".backup '$CHEMIN_DB.backup'"
docker cp $NOM_CONTENEUR:"$CHEMIN_DB.backup" "$BACKUP_FILE"
docker exec $NOM_CONTENEUR rm -f "$CHEMIN_DB.backup"

echo "✅ Sauvegarde créée: $(basename $BACKUP_FILE) ($(du -h "$BACKUP_FILE" | cut -f1))"

# 3. Optimisation SQLite
echo "🔵 Optimisation de la base de données..."
docker exec $NOM_CONTENEUR sqlite3 "$CHEMIN_DB" "VACUUM;"
docker exec $NOM_CONTENEUR sqlite3 "$CHEMIN_DB" "PRAGMA optimize;"
docker exec $NOM_CONTENEUR sqlite3 "$CHEMIN_DB" "PRAGMA analysis_limit=400; ANALYZE;"

# 4. Vérification
echo "🔵 Vérification de l'intégrité..."
INTEGRITE=$(docker exec $NOM_CONTENEUR sqlite3 "$CHEMIN_DB" "PRAGMA integrity_check;")
if [ "$INTEGRITE" = "ok" ]; then
    echo "✅ Base de données intègre"
else
    echo "⚠️  Problème détecté: $INTEGRITE"
fi

# 5. Nettoyage des anciennes sauvegardes
echo "🔵 Nettoyage des anciennes sauvegardes..."
find "$BACKUP_DIR" -name "forgejo-backup-*.db" -type f -mtime +$RETENTION_JOURS -delete
echo "✅ Sauvegardes de plus de $RETENTION_JOURS jours supprimées"

# 6. Statistiques
echo "🔵 Statistiques de la base:"
docker exec $NOM_CONTENEUR sqlite3 "$CHEMIN_DB" "
SELECT 
    name, 
    printf('%.2f', CAST(pgsize AS REAL) / 1024 / 1024) || ' MB' as taille
FROM dbstat 
WHERE name NOT LIKE 'sqlite_%' 
ORDER BY pgsize DESC 
LIMIT 10;"

echo "========================================"
echo "✅ Maintenance terminée avec succès!"
echo "========================================"