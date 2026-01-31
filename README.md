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
# Remplir WOODPECKER_AGENT_SECRET

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

## 🚦 Première utilisation

1. Accéder à http://localhost:5333
2. Créer le compte administrateur (premier utilisateur)
3. Créer une OAuth App dans Forgejo (**Paramètres → Applications**) :
   - URL de callback : `http://localhost:5444/authorize`
4. Ajouter les identifiants dans `.env` :
   ```env
   WOODPECKER_FORGEJO_CLIENT=votre_client_id
   WOODPECKER_FORGEJO_SECRET=votre_client_secret
   ```
5. Accéder à http://localhost:5444 et se connecter via Forgejo

## 🔒 Variables d'environnement

| Variable | Description |
|----------|-------------|
| `WOODPECKER_AGENT_SECRET` | Secret de communication agent-serveur (obligatoire) |
| `WOODPECKER_FORGEJO_CLIENT` | Client OAuth Forgejo |
| `WOODPECKER_FORGEJO_SECRET` | Secret OAuth Forgejo |

## 🛠️ Commandes

```bash
# Logs en temps réel
docker compose logs -f

# Redémarrer
docker compose restart

# Arrêter
docker compose down
```

## 📅 Maintenance

- **Optimisation DB** : Chaque dimanche à 3h00 (automatique)
- **Logs** : Répertoire `./logs/`

## 📄 Licence

MIT