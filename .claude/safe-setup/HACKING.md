# Environnement de développement avec Claude Code

Ce setup Docker fournit un environnement sandboxé avec tous les outils nécessaires :
- Python 3.12 avec pandas, requests, BeautifulSoup, botasaurus, playwright
- Docker-in-Docker (daemon isolé dans le conteneur)
- PostgreSQL
- Claude Code CLI
- rtk (compression des sorties CLI)

## Prérequis

1. Docker et Docker Compose installés sur l'hôte
2. Un compte Claude Code (clé API Anthropic)

## Démarrage

```bash
cd .claude/safe-setup

# Créer le fichier .env à partir du template
cp .env.example .env

# Éditer .env avec votre identité Git
# GIT_USER_NAME=Votre Nom
# GIT_USER_EMAIL=votre@email.com

# Construire et démarrer les conteneurs
make up

# Entrer dans l'environnement
make shell
```

## Données persistantes

- **Credentials et historique Claude** : volume Docker `claude-history`, persiste entre les redémarrages. L'authentification ne se fait qu'une seule fois.
- **Historique Bash** : volume Docker `bash-history`
- **Images et conteneurs Docker internes** : volume Docker `docker-data`, les images construites par Claude sont conservées entre les sessions.
- **Configuration Git** : définie automatiquement via les variables `GIT_USER_NAME` et `GIT_USER_EMAIL`

## Docker-in-Docker

Le conteneur embarque un daemon Docker complet (mode DinD). Claude peut :
- Construire des images (`docker build`)
- Lancer des services (`docker compose up`)
- Tester des configurations Docker de manière isolée

Les conteneurs lancés par Claude tournent **dans** le conteneur de dev, pas sur l'hôte.
Le mode `privileged` est requis pour le fonctionnement du daemon Docker interne.

## rtk (Rust Token Killer)

rtk compresse automatiquement les sorties de commandes CLI avant qu'elles n'atteignent
la fenêtre de contexte de Claude (60-90% de réduction de tokens).

Le hook auto-rewrite est activé automatiquement au premier démarrage.

```bash
# Voir les statistiques de compression
rtk gain
```

## Dans le conteneur

Vous êtes l'utilisateur `osint` dans `/workspace` (la racine du projet).

```bash
# Lancer Claude Code
claude

# Se connecter à PostgreSQL
psql
```

PostgreSQL est pré-configuré via les variables d'environnement.

## Commandes Make

| Commande | Description |
|----------|-------------|
| `make up` | Construire et démarrer les conteneurs |
| `make down` | Arrêter les conteneurs |
| `make shell` | Entrer dans le conteneur de dev |
| `make restart` | Redémarrer |
| `make logs` | Suivre les logs |
| `make status` | État des conteneurs |
| `make clean` | Supprimer conteneurs et images |
