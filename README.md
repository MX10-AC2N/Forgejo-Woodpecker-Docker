# 🚀 Forgejo + Woodpecker CI - Stack DevOps Légère

## Description

Stack DevOps légère et auto-hébergée combinant **Forgejo 14** (gestion de code source) et **Woodpecker CI** (intégration continue), déployée via Docker et Docker Compose. Configuration simple et minimaliste pour un usage personnel ou petites équipes.

## ✨ Caractéristiques

- **Légèreté** : Image Alpine pour Woodpecker, SQLite pour Forgejo
- **Simplicité** : Configuration minimale, pas de base de données externe
- **Intégration** : Connexion native Forgejo ↔ Woodpecker
- **Maintenance** : Optimisation automatique de la base de données

## 📋 Prérequis

| Prérequis | Version minimum |
|-----------|-----------------|
| Docker Engine | 20.10+ |
| Docker Compose | v2 |
| RAM | 2 Go |
| Ports libres | 5333, 5222, 5444 |

## 🔧 Installation

```bash
# Cloner le repository
git clone https://github.com/MX10-AC2N/Forgejo-Woodpecker-Docker.git
cd Forgejo-Woodpecker-Docker

# Configurer les variables d'environnement
nano .env

# Lancer la stack
docker compose up -d --build
```

## 🌐 Accès aux services

| Service | URL | Port |
|---------|-----|------|
| Interface Forgejo | http://localhost:5333 | 5333 |
| Interface Woodpecker | http://localhost:5444 | 5444 |
| SSH Git | ssh://git@localhost:5222 | 5222 |

## 📁 Structure du projet

```
Forgejo-Woodpecker-Docker/
├── docker-compose.yml      # Orchestration des services
├── Dockerfile.forgejo      # Forgejo 14 avec cron
├── .env                    # Variables d'environnement
├── scripts/
│   ├── optimize-db.sh      # Optimisation SQLite
│   └── entrypoint-cron.sh  # Point d'entrée avec cron
├── backups/                # Répertoire de sauvegardes
└── logs/                   # Logs applicatifs
```

## 🔒 Configuration du fichier .env

Le fichier `.env` contient toutes les variables sensibles nécessaires au fonctionnement de la stack.

### WOODPECKER_AGENT_SECRET (Obligatoire)

Secret de communication entre l'agent et le serveur Woodpecker. **Doit être identique des deux côtés.**

```bash
# Générer un secret aléatoire
openssl rand -hex 32
```

Exemple dans `.env` :
```env
WOODPECKER_AGENT_SECRET=a1b2c3d4e5f6g7h8i9j0...
```

### WOODPECKER_FORGEJO_CLIENT et WOODPECKER_FORGEJO_SECRET (Optionnel mais recommandé)

Ces variables permettent l'authentification OAuth via Forgejo pour accéder à Woodpecker.

#### Étape 1 : Créer l'OAuth App dans Forgejo

1. Se connecter à Forgejo : http://localhost:5333
2. Aller dans **Paramètres du profil** → **Applications**
3. Cliquer sur **Nouvelle OAuth App**
4. Remplir le formulaire :
   - **Nom de l'application** : Woodpecker CI
   - **URL de redirection** : `http://localhost:5444/authorize`
   - **URL de la page d'accueil** (optionnel) : `http://localhost:5444`
5. Cliquer sur **Créer l'application**

#### Étape 2 : Récupérer les identifiants

Après création, Forgejo affiche le **Client ID** et le **Client Secret**. Les copier dans le fichier `.env` :

```env
WOODPECKER_FORGEJO_CLIENT=VotreClientIDici
WOODPECKER_FORGEJO_SECRET=VotreClientSecretici
```

> **Note** : Si ces variables sont laissées vides, Woodpecker fonctionnera sans OAuth (accès public).

### WOODPECKER_GITHUB_CLIENT et WOODPECKER_GITHUB_SECRET (Optionnel)

Pour utiliser GitHub comme fournisseur OAuth au lieu de Forgejo :

1. Créer une OAuth App sur GitHub (Developer settings → OAuth Apps)
2. URL de callback : `http://localhost:5444/authorize`
3. Ajouter les identifiants dans `.env` :
   ```env
   WOODPECKER_GITHUB=true
   WOODPECKER_GITHUB_CLIENT=VotreGitHubClientID
   WOODPECKER_GITHUB_SECRET=VotreGitHubClientSecret
   ```

## 🚦 Première utilisation

1. Lancer la stack : `docker compose up -d --build`
2. Accéder à http://localhost:5333
3. Créer le compte administrateur (premier utilisateur enregistré)
4. Créer une OAuth App dans Forgejo (voir section ci-dessus)
5. Ajouter les identifiants OAuth dans `.env`
6. Redémarrer Woodpecker : `docker compose restart woodpecker-server`
7. Se connecter à http://localhost:5444 via Forgejo

## 🛠️ Commandes

```bash
# Logs en temps réel
docker compose logs -f

# Logs d'un service spécifique
docker compose logs -f woodpecker-server

# Redémarrer un service
docker compose restart forgejo
docker compose restart woodpecker-server
docker compose restart woodpecker-agent

# Arrêter la stack
docker compose down

# Supprimer les données (Attention : perte de données)
docker compose down -v
```

## 📅 Maintenance

- **Optimisation DB** : Chaque dimanche à 3h00 (automatique via cron)
- **Logs** : Répertoire `./logs/`
- **Sauvegardes** : À configurer selon vos besoins

## 📄 Licence

MIT