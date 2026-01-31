#🚀 Forgejo + Woodpecker CI - Stack DevOps Personnelle

Bienvenue dans votre stack DevOps personnelle ! Cette configuration vous permet d'avoir votre propre Forgejo (alternative à GitHub) couplé à Woodpecker CI pour vos projets, le tout dans des conteneurs Docker légers et optimisés.

✨ Ce que vous allez installer

· Forgejo 14.0.2 : Votre propre forge logicielle (comme GitHub mais auto-hébergé)
· Woodpecker CI 3.13.0 : Système d'intégration continue (CI/CD) moderne
· Base de données SQLite : Simple et suffisante pour usage personnel
· Optimisation automatique : Maintenance hebdomadaire incluse
· Synchronisation GitHub : Optionnelle pour garder vos dépôts synchronisés

📋 Prérequis

· Docker et Docker Compose installés
· Environ 1 Go d'espace disque libre
· Un peu de temps pour la configuration initiale

🚀 Installation rapide

```bash
# 1. Cloner ou créer le projet
mkdir forgejo-personnel && cd forgejo-personnel

# 2. Créer la structure de fichiers
touch docker-compose.yml .env Dockerfile.forgejo
mkdir -p scripts backups logs

# 3. Copier les configurations (voir sections ci-dessous)
# 4. Lancer la stack
docker-compose up -d
```

🔧 Configuration pas à pas

Étape 1 : Fichier docker-compose.yml

```yaml
version: '3.8'

services:
  forgejo:
    build:
      context: .
      dockerfile: Dockerfile.forgejo
    container_name: forgejo
    restart: unless-stopped
    environment:
      - USER_UID=1000
      - USER_GID=1000
      - FORGEJO__database__DB_TYPE=sqlite3
      - FORGEJO__database__PATH=/data/forgejo.db
    volumes:
      - forgejo_data:/data
      - ./backups:/backups
    ports:
      - "3000:3000"   # Interface web
      - "2222:22"     # SSH (port remappé)

  woodpecker-server:
    image: woodpeckerci/woodpecker-server:v3.13.0
    container_name: woodpecker-server
    restart: unless-stopped
    depends_on:
      - forgejo
    environment:
      - WOODPECKER_HOST=http://localhost:8000
      - WOODPECKER_AGENT_SECRET=${WOODPECKER_AGENT_SECRET}
      - WOODPECKER_GITEA=true
      - WOODPECKER_GITEA_URL=http://forgejo:3000
    ports:
      - "8000:8000"

  woodpecker-agent:
    image: woodpeckerci/woodpecker-agent:v3.13.0
    container_name: woodpecker-agent
    restart: unless-stopped
    depends_on:
      - woodpecker-server
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock

volumes:
  forgejo_data:
  woodpecker_server_data:
```

Étape 2 : Fichier .env (SECURITÉ IMPORTANTE !)

```bash
# Générer avec : openssl rand -base64 24
WOODPECKER_AGENT_SECRET=votre_secret_tres_long_et_unique_ici

# Optionnel : pour synchroniser avec GitHub
WOODPECKER_GITHUB_CLIENT=
WOODPECKER_GITHUB_SECRET=
```

Étape 3 : Dockerfile personnalisé (Dockerfile.forgejo)

```dockerfile
FROM codeberg.org/forgejo/forgejo:1.21.9
RUN apk add --no-cache bash sqlite
COPY scripts/optimize-db.sh /scripts/
COPY scripts/entrypoint-cron.sh /scripts/
RUN chmod +x /scripts/*.sh
ENTRYPOINT ["/scripts/entrypoint-cron.sh"]
```

Étape 4 : Scripts d'optimisation

scripts/optimize-db.sh - [Copier le script complet du message précédent]
scripts/entrypoint-cron.sh - [Copier le script d'entrée du message précédent]

Étape 5 : Lancement final

```bash
# Donner les permissions aux scripts
chmod +x scripts/*.sh

# Construire l'image Forgejo personnalisée
docker-compose build forgejo

# Tout démarrer
docker-compose up -d
```

🌐 Accès aux services

· Forgejo : http://localhost:3000
· Woodpecker CI : http://localhost:8000
· SSH Git : ssh -p 2222 git@localhost

🔐 Configuration initiale

Forgejo (première connexion)

1. Rendez-vous sur http://localhost:3000
2. Complétez l'installation (SQLite par défaut)
3. Créez votre compte administrateur
4. Créez votre premier dépôt

Woodpecker CI

1. Rendez-vous sur http://localhost:8000
2. Cliquez sur "Se connecter avec Forgejo"
3. Autorisez l'application
4. Activez vos premiers dépôts pour CI/CD

🔄 Synchronisation avec GitHub (Optionnel)

Méthode 1 : Via Woodpecker

1. Créez une OAuth App sur GitHub
2. Ajoutez les identifiants dans .env
3. Redémarrez Woodpecker

Méthode 2 : Miroir Forgejo → GitHub

Dans chaque dépôt Forgejo :

1. Paramètres → Miroir du dépôt
2. URL : https://github.com/votre-utilisateur/depot.git
3. Token : Votre token GitHub avec permission repo

🛠️ Maintenance automatique

Votre système se maintient tout seul ! Tous les dimanches à 3h du matin :

· ✅ Sauvegarde automatique de la base
· ✅ Optimisation SQLite (VACUUM, ANALYZE)
· ✅ Nettoyage des sauvegardes anciennes

Commandes manuelles utiles :

```bash
# Voir les logs de maintenance
docker exec forgejo tail -f /data/forgejo-maintenance.log

# Tester manuellement l'optimisation
docker exec forgejo /scripts/optimize-db.sh

# Vérifier l'état des services
docker-compose ps

# Voir les logs en temps réel
docker-compose logs -f
```

📦 Sauvegarde et restauration

Sauvegarde manuelle

```bash
# Sauvegarde complète
docker-compose down
tar -czf backup-$(date +%Y%m%d).tar.gz backups/ forgejo_data/
docker-compose up -d
```

Restauration

```bash
# Arrêter les services
docker-compose down

# Restaurer les données
tar -xzf backup-YYYYMMDD.tar.gz

# Redémarrer
docker-compose up -d
```

🚨 Dépannage rapide

Problème : "Port déjà utilisé"

```bash
# Vérifier quel service utilise le port
sudo lsof -i :3000

# Ou modifier les ports dans docker-compose.yml
ports:
  - "3001:3000"  # Changer le port externe
```

Problème : "Permission denied"

```bash
# Donner les bonnes permissions aux scripts
chmod +x scripts/*.sh

# Vérifier les permissions des volumes
docker-compose down
sudo chown -R $USER:$USER ./backups ./logs
docker-compose up -d
```

Problème : "Woodpecker ne se connecte pas à Forgejo"

```bash
# Vérifier la connexion réseau interne
docker exec woodpecker-server ping forgejo

# Vérifier que Forgejo répond
curl http://forgejo:3000/api/health
```

📈 Monitoring de l'état

```bash
# Taille de la base de données
docker exec forgejo sqlite3 /data/forgejo.db \
  "SELECT page_count * page_size / 1024 / 1024 as 'Taille (MB)' \
   FROM pragma_page_count(), pragma_page_size();"

# Nombre de dépôts
docker exec forgejo sqlite3 /data/forgejo.db \
  "SELECT COUNT(*) as 'Total dépôts' FROM repository;"

# Espace disque utilisé
docker system df
```

🔄 Mise à jour

Mise à jour de Forgejo

1. Modifier la version dans Dockerfile.forgejo
2. docker-compose build forgejo
3. docker-compose up -d

Mise à jour de Woodpecker

1. Modifier les tags dans docker-compose.yml
2. docker-compose pull
3. docker-compose up -d

🤝 Contribuer à ce projet

Cette configuration est faite pour vous ! Vous pouvez :

· Modifier les fréquences de maintenance
· Ajouter d'autres services (Notif, Monitoring)
· Améliorer les scripts d'optimisation

📚 Ressources utiles

· Documentation Forgejo
· Documentation Woodpecker CI
· Guide SQLite Optimisation

---

✨ Et voilà ! Vous avez maintenant une plateforme DevOps complète, légère, et qui se maintient toute seule. Parfait pour vos projets personnels.

Un problème ? Une question ? N'hésitez pas à créer une issue ou à contribuer !

---

Dernière mise à jour : Configuration optimisée pour usage personnel - Maintenance automatique incluse 🎯