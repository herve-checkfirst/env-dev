# Environnement de développement Python avec Claude Code

Un environnement Docker sandboxé pour développer en Python avec l'aide de Claude Code.

Très largement inspiré par Bernard Lambeau https://github.com/blambeau, et notamment ce tutoriel :

https://www.loom.com/share/ef65c6ebfc35491783ff0a6067447dd4


## Prérequis

- Docker et Docker Compose installés
- Un compte Claude Code (clé API Anthropic)

## Démarrage rapide

```bash
# 1. Aller dans le répertoire de configuration
cd .claude/safe-setup

# 2. Configurer votre identité Git (optionnel)
cp .env.example .env
# Éditer .env avec vos infos :
# GIT_USER_NAME=Votre Nom
# GIT_USER_EMAIL=votre@email.com

# 3. Construire et démarrer le conteneur
make up

# 4. Entrer dans l'environnement
make shell
```

## Utilisation

Une fois dans le conteneur, vous êtes l'utilisateur `osint` dans `/workspace` (la racine du projet).

### Python

```bash
# REPL Python
python

# Jupyter Notebook (accessible sur http://localhost:8888)
jupyter notebook --ip=0.0.0.0

# Lancer un script
python mon_script.py
```

### Linting et formatage

```bash
# Vérifier le style avec flake8
flake8 mon_script.py

# Formater avec black
black mon_script.py

# Trier les imports
isort mon_script.py
```

### Docker (Docker-in-Docker)

Un daemon Docker complet tourne à l'intérieur du conteneur (mode DinD).
Claude peut construire des images, lancer des `docker compose up` et tester des
configurations Docker de manière totalement isolée, sans affecter l'hôte.

Les images et conteneurs créés dans le conteneur sont persistés via un volume Docker dédié.

```bash
# Vérifier que le daemon Docker interne fonctionne
docker ps

# Vérifier la version de Compose
docker compose version

# Tester un docker-compose.yml
docker compose -f mon-projet/docker-compose.yml up -d
```

### rtk ([Rust Token Killer](https://github.com/rtk-ai/rtk))

rtk est un proxy CLI qui compresse les sorties de commandes (git, docker, npm, etc.)
avant qu'elles n'atteignent la fenêtre de contexte de Claude. Reduction de 60 a 90% des tokens.

Le hook auto-rewrite est active automatiquement au premier demarrage du conteneur.
Les commandes sont reecrites de maniere transparente (`git status` devient `rtk git status`).

```bash
# Voir les statistiques de compression
rtk gain
```

### Claude Code

```bash
# Lancer Claude Code
claude
```

## Outils installés

| Outil | Description |
|-------|-------------|
| Python 3.12 | Interpréteur Python |
| pandas | Manipulation de données |
| requests | Requêtes HTTP |
| beautifulsoup4 | Parsing HTML/XML |
| jupyter | Notebooks interactifs |
| black | Formatage de code |
| flake8 | Linting |
| isort | Tri des imports |
| Docker Engine (DinD) | Daemon Docker isolé dans le conteneur |
| Docker Compose plugin | Commande `docker compose` disponible dans le conteneur |
| [rtk](https://github.com/rtk-ai/rtk) | Compression des sorties CLI pour réduire la consommation de tokens |

## Commandes Make

| Commande | Description |
|----------|-------------|
| `make up` | Construire et démarrer le conteneur |
| `make down` | Arrêter le conteneur |
| `make shell` | Entrer dans le conteneur |
| `make restart` | Redémarrer |
| `make logs` | Voir les logs |
| `make status` | État du conteneur |
| `make clean` | Supprimer conteneur et images |

## Structure du projet

```
.
├── .claude/
│   ├── commands/       # Agents Claude personnalisés
│   ├── safe-setup/     # Configuration Docker
│   ├── tasks/          # Gestion des tâches
│   └── settings.json   # Permissions Claude
├── CLAUDE.md           # Instructions pour Claude
└── README.md           # Ce fichier
```

## Agents disponibles

Invoquez ces agents avec `/nom` dans Claude Code :

- `/sceptic` - Propose des tests pour trouver des bugs
- `/rigorous` - Vérifie la cohérence du projet
- `/einstein` - Traque la complexité inutile
- `/paranoid` - Audit de sécurité
- `/grammarian` - Qualité du code et de la documentation
