#  Forgejo-Woodpecker-Docker


📝 Fichier .env à créer

Créez un fichier nommé .env dans le même répertoire et ajoutez-y ces variables (remplacez les valeurs entre <>):

#=== SECRETS CRITIQUES (Générez-les avec `openssl rand -base64 24`) ===
FORGEJO_JWT_SECRET=<votre_secret_forgejo_très_long>
WOODPECKER_AGENT_SECRET=<votre_secret_woodpecker_très_long>

#=== APPLICATION OAUTH FORGEJO (Pour connecter Woodpecker à Forgejo) ===
# 1. Allez dans Forgejo (http://localhost:3000) > "Paramètres" > "Applications"
# 2. Créez une application OAuth2 :
#    - Nom : "Woodpecker CI"
#    - URI de redirection : http://localhost:8000/authorize
# 3. Copiez l'ID Client et le Secret ici :
WOODPECKER_FORGEJO_CLIENT=<client_id_de_votre_app_forgejo>
WOODPECKER_FORGEJO_SECRET=<client_secret_de_votre_app_forgejo>

#=== APPLICATION OAUTH GITHUB (Optionnel - Pour la synchro directe) ===
# 1. Créez une OAuth App sur GitHub : https://github.com/settings/developers
# 2. Homepage URL : http://localhost:3000
# 3. Authorization callback : http://localhost:8000/authorize
# 4. Copiez l'ID Client et le Secret ici :
WOODPECKER_GITHUB_CLIENT=<votre_client_id_github>
WOODPECKER_GITHUB_SECRET=<votre_client_secret_github>

#=== CONFIGURATION VARIABLE ===
WOODPECKER_HOST=http://localhost:8000
```

🚀 Instructions de déploiement

1. Préparation :
   ```bash
   mkdir forgejo-woodpecker && cd forgejo-woodpecker
   touch docker-compose.yml .env
   # Copiez-collez le contenu ci-dessus dans chaque fichier
   ```
2. Générez les secrets et complétez le fichier .env :
   ```bash
   openssl rand -base64 24
   # Utilisez la sortie pour FORGEJO_JWT_SECRET et WOODPECKER_AGENT_SECRET
   ```
3. Démarrez la stack :
   ```bash
   docker-compose up -d
   ```
4. Configuration initiale :
   · Accédez à Forgejo : http://localhost:3000
     · Complétez l'installation (choisissez SQLite3).
     · Créez un administrateur.
     · Créez l'application OAuth2 comme décrit ci-dessus et mettez à jour votre fichier .env.
   · Accédez à Woodpecker CI : http://localhost:8000
     · À la première connexion, choisissez "Se connecter avec Forgejo".
     · Autorisez l'application. Vos dépôts Forgejo apparaîtront.

🔧 Synchronisation GitHub avec Forgejo

Après avoir configuré l'application OAuth GitHub dans Woodpecker (étape optionnelle du .env), vous pouvez aussi activer la synchronisation de dépôts (miroir) directement dans Forgejo :

1. Dans un projet Forgejo, allez dans "Paramètres" > "Miroir du dépôt".
2. Remplissez l'URL GitHub (https://github.com/utilisateur/depot.git).
3. Pour l'authentification, utilisez un Personal Access Token GitHub (avec la permission repo).

💡 Bonnes pratiques additionnelles

· Vérification : Consultez les logs après le démarrage : docker-compose logs -f.
· Sauvegarde : Sauvegardez régulièrement les volumes Docker (forgejo_data, etc.).
· Mise à jour : Pour mettre à jour une image, modifiez le tag (ex: :1.21.9) dans docker-compose.yml et relancez : docker-compose pull && docker-compose up -d.
