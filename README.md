# Forgejo with Woodpecker
## Docker Installation Guide

This project provides an easy way to deploy a **Forgejo** and **Woodpecker CI** stack using Docker. It is designed to facilitate continuous integration with Forgejo (a GitHub alternative) and Woodpecker CI. This README covers creating a `.env` file, deploying with Docker, and configuring GitHub synchronization with Forgejo.

---

## 📝 Create the `.env` File

Create a `.env` file in the same directory as this `README.md` and add the following variables (replace values between `< >` with your specific information):

### === CRITICAL SECRETS (Generate using `openssl rand -base64 24`) ===
FORGEJO_JWT_SECRET=<your_very_long_forgejo_secret>
WOODPECKER_AGENT_SECRET=<your_very_long_woodpecker_secret>

### === FORGEJO OAUTH APPLICATION (To connect Woodpecker to Forgejo) ===
1. Go to Forgejo (http://localhost:3000) > "Settings" > "Applications"
2. Create an OAuth2 application:
    - Name: "Woodpecker CI"
    - Redirect URI: http://localhost:8000/authorize
3. Copy the Client ID and Secret here:
WOODPECKER_FORGEJO_CLIENT=<your_forgejo_app_client_id>
WOODPECKER_FORGEJO_SECRET=<your_forgejo_app_client_secret>

### === GITHUB OAUTH APPLICATION (Optional - For direct sync) ===
1. Create an OAuth App on GitHub: https://github.com/settings/developers
2. Homepage URL: http://localhost:3000
3. Authorization callback: http://localhost:8000/authorize
4. Copy the Client ID and Secret here:
WOODPECKER_GITHUB_CLIENT=<your_github_client_id>
WOODPECKER_GITHUB_SECRET=<your_github_client_secret>

### === CONFIGURATION VARIABLE ===
WOODPECKER_HOST=http://localhost:8000

---

## 🚀 Deployment Instructions

### 1. Preparation

Start by creating the project directory and the necessary files:
```bash
mkdir forgejo-woodpecker && cd forgejo-woodpecker
touch docker-compose.yml .env
```
Paste the content from this README into each file.
2. Generate Secrets and Complete the .env File
Run the following command to generate secure secrets:
```bash
openssl rand -base64 24
```
Use the output to fill FORGEJO_JWT_SECRET and WOODPECKER_AGENT_SECRET in the .env file.
3. Start the Stack
Start the services with Docker Compose:
```bash
docker-compose up -d
```
4. Initial Setup
Forgejo
Access Forgejo: http://localhost:3000
Complete the installation (choose SQLite3 as the database).
Create an administrator user.
Create the OAuth2 application:
Name: "Woodpecker CI"
Redirect URI: http://localhost:8000/authorize
Copy the Client ID and Secret of the OAuth2 application, then update your .env file.
Woodpecker CI
Access Woodpecker CI: http://localhost:8000
On the first login, choose "Login with Forgejo."
Authorize the OAuth application, and your Forgejo repositories will appear in Woodpecker CI.
🔧 GitHub Synchronization with Forgejo (Optional)
If you want to synchronize your GitHub repositories with Forgejo, follow these steps:
Create an OAuth application on GitHub: https://github.com/settings/developers
Set the homepage URL: http://localhost:3000
Set the authorization callback: http://localhost:8000/authorize
Copy the Client ID and Secret into your .env file under the WOODPECKER_GITHUB_CLIENT and WOODPECKER_GITHUB_SECRET sections.
Add a Repository Mirror
In a Forgejo project, go to Settings > Repository Mirror.
Add the GitHub repository URL to sync: https://github.com/username/repository.git.
For authentication, use a GitHub Personal Access Token (with repo permissions).
💡 Additional Best Practices
Log Check: After starting the services, check the logs to ensure everything is running correctly:
```bash
docker-compose logs -f
```
•Backups: Remember to regularly back up Docker volumes (e.g., forgejo_data).
•Updates: To update Docker images, modify the tag (e.g., :1.21.9) in the docker-compose.yml file, then run:
```bash
docker-compose pull && docker-compose up -d
```
Good installation and usage of Forgejo and Woodpecker CI! 🚀
