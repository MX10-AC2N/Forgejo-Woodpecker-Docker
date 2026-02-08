# 🚀 Forgejo + Woodpecker CI - Stack Automatisée

[![CI/CD Status](https://img.shields.io/badge/CI%2FCD-passing-brightgreen)]()
[![Docker Compose](https://img.shields.io/badge/docker--compose-2.0+-blue)]()
[![License](https://img.shields.io/badge/license-MIT-green)]()

Stack complète de CI/CD avec [Forgejo](https://forgejo.org/) (Git auto-hébergé) et [Woodpecker CI](https://woodpecker-ci.org/), entièrement en Docker. **Zéro configuration manuelle, déploiement en 5 minutes.**

## ✨ Ce qu'il y a dedans

- ✅ OAuth automatique (pas besoin de cliquer partout)
- ✅ Déploiement en 1 commande : `docker compose up -d`
- ✅ Healthchecks pour chaque service
- ✅ Script de validation automatique
- ✅ Prêt pour la production (sécurité, backup, etc)

## 🎯 Pourquoi ça change la vie

Les autres stacks Forgejo + Woodpecker c'est :
- Configuration manuelle d'OAuth via l'interface
- Redémarrage manuel de Woodpecker
- Tests manuels pour vérifier que ça marche

**Nous, on a automatisé tout ça.** OAuth se crée tout seul via une API, les credentials se passent entre les services, et 2 minutes après tu peux pusher du code et voir les pipelines s'exécuter.

---

## 📦 Prérequis

```bash
Docker Engine 20.10+
Docker Compose 2.0+
Git 2.0+
RAM : 2 GB minimum (4 GB recommended)
Ports libres : 5222, 5333, 5444
```

**Vérif rapide :**
```bash
docker --version
docker compose version
sudo netstat -tulpn | grep -E ':(5222|5333|5444)'
```

---

## 🚀 Installation (5 min)

### 1️⃣ Clone et config

```bash
git clone https://github.com/MX10-AC2N/Forgejo-Woodpecker-Docker.git
cd Forgejo-Woodpecker-Docker

cp .env.example .env
nano .env
```

**À changer obligatoirement :**
```bash
ADMIN_PASSWORD=UnMotDePasseFort123!
WOODPECKER_AGENT_SECRET=$(openssl rand -base64 48)
```

**Laisse vides (auto-générés) :**
```bash
WOODPECKER_FORGEJO_CLIENT=
WOODPECKER_FORGEJO_SECRET=
```

### 2️⃣ Lance

```bash
docker compose build
docker compose up -d
```

### 3️⃣ Attends 2-3 min et valide

```bash
chmod +x scripts/validate-stack.sh
./scripts/validate-stack.sh
```

✅ Résultat attendu :
```
✅ STACK VALIDÉE !

URLs :
   Forgejo    : http://localhost:5333
   Woodpecker : http://localhost:5444
```

### 4️⃣ Login

**Forgejo** : http://localhost:5333
- Login : `forgejo-admin`
- Password : Celui du `.env`

**Woodpecker** : http://localhost:5444
- Clique "Login" → Redirect vers Forgejo → Autoriser l'app → C'est bon ✅

---

## 💻 Utilisation

### Crée un dépôt + pipeline

1. Va sur Forgejo, crée un repo
2. Ajoute un fichier `.woodpecker.yml` à la racine :

```yaml
when:
  branch: main

steps:
  build:
    image: alpine:latest
    commands:
      - echo "Hello from Woodpecker! 🚀"
      - date
```

3. Push → Le pipeline s'exécute automatiquement sur Woodpecker ✨

### Exemples rapides

**Node.js :**
```yaml
steps:
  test:
    image: node:20-alpine
    commands:
      - npm ci
      - npm test
  build:
    image: node:20-alpine
    commands:
      - npm run build
```

**Python :**
```yaml
steps:
  test:
    image: python:3.11-slim
    commands:
      - pip install -r requirements.txt
      - pytest
```

**Docker :**
```yaml
steps:
  build:
    image: plugins/docker
    settings:
      repo: myapp
      tags: latest
```

---

## 🔧 Commandes utiles

```bash
# Logs en direct
docker compose logs -f

# Logs d'un service
docker compose logs -f forgejo

# Redémarrer un truc
docker compose restart woodpecker-server

# État de tout
docker compose ps

# Nettoyer (⚠️ attention, ça supprime les données)
docker compose down -v
```

---

## 🐛 Ça marche pas ?

### OAuth pas configuré
```bash
# Vérifie que le fichier existe
docker compose exec forgejo cat /shared/oauth-credentials.env

# Redémarre Woodpecker
docker compose restart woodpecker-server
```

### Forgejo redémarre en boucle
```bash
docker compose logs forgejo --tail 50
# Puis fix les permissions si c'est ça
sudo chown -R 1000:1000 volumes/forgejo/
```

### Port déjà utilisé
```bash
sudo netstat -tulpn | grep :5333
# Change le port dans .env et relance
```

### Plus rien ne marche ?
```bash
# ⚠️ ATTENTION : Supprime tout !
docker compose down -v
rm -rf volumes/
docker compose up -d
```

---

## 🔒 Sécurité pour la prod

**Checklist** :
- [ ] Mot de passe admin vraiment fort (16+ caractères)
- [ ] WOODPECKER_AGENT_SECRET aléatoire (48+ caractères)
- [ ] HTTPS avec reverse proxy (Traefik, Nginx, Caddy)
- [ ] Firewall : ouvrir que 80 et 443
- [ ] Backup automatique via cron

**Générer des secrets forts :**
```bash
openssl rand -base64 32  # Mot de passe
openssl rand -base64 48  # Secret agent
```

**Backup auto (ajoute dans crontab) :**
```bash
crontab -e
# 0 2 * * * cd /chemin && ./scripts/backup.sh
```

---

## 📊 Architecture

```
┌─────────────────────────────────┐
│       Docker Compose Stack      │
├─────────────────────────────────┤
│                                 │
│  Forgejo ←→ /shared/ ←→ Woodpecker
│   :5333        vol      Server:5444
│                           ↓
│                      Woodpecker
│                         Agent
│                                 │
└─────────────────────────────────┘
```

| Service | Port | Use |
|---------|------|-----|
| **Forgejo** | 5333 (HTTP)<br>5222 (SSH) | Git repo |
| **Woodpecker Server** | 5444 | Web UI + API |
| **Woodpecker Agent** | - | Run pipelines |

---

## 📖 Docs + Help

- 🐛 [Issues](../../issues)
- 💬 [Discussions](../../discussions)
- [Forgejo Docs](https://forgejo.org/docs/)
- [Woodpecker Docs](https://woodpecker-ci.org/docs/)
- [Docker Docs](https://docs.docker.com/)

---

## 📜 Licence

MIT - Fais ce que tu veux avec ! 📝

---

## 🙏 Merci à

- [Forgejo](https://forgejo.org/) - Git libre et sympa
- [Woodpecker CI](https://woodpecker-ci.org/) - CI/CD moderne
- [Docker](https://www.docker.com/) - Conteneurs magiques

---

<div align="center">

**Fait avec ❤️ pour la communauté dev**

[⬆ Haut](#-forgejo--woodpecker-ci---stack-automatisée)

</div>