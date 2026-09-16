# Environnement de développement Python avec Claude Code

Un environnement Docker sandboxé pour développer en Python avec l'aide de Claude Code.

*[English version](README_en.md) — [Guide détaillé de l'environnement Docker](.claude/safe-setup/HACKING.md)*

Ce dépôt est conçu comme un **template** : clonez-le pour chaque nouveau projet.
Chaque clone dispose de ses propres volumes Docker (historique Claude, images Docker, etc.)
grâce au préfixage automatique par Docker Compose (basé sur le nom du répertoire parent).

Très largement inspiré des travaux de [Bernard Lambeau](https://github.com/blambeau),
et notamment de [ce tutoriel](https://www.loom.com/share/ef65c6ebfc35491783ff0a6067447dd4).


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

# 3. Construire et démarrer les conteneurs
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

# Lancer un script
python mon_script.py
```

### Linting et formatage

Le linting et le formatage sont assurés par [ruff](https://docs.astral.sh/ruff/),
qui remplace flake8, black et isort en un seul outil.

```bash
# Vérifier le code
ruff check mon_script.py

# Corriger automatiquement ce qui peut l'être
ruff check --fix mon_script.py

# Formater le code
ruff format mon_script.py
```

### Docker (Docker-in-Docker)

Un daemon Docker complet tourne à l'intérieur du conteneur (mode DinD).
Claude peut construire des images, lancer des `docker compose up` et tester des
configurations Docker sans toucher au Docker de l'hôte.

> **Le conteneur n'est pas une frontière de sécurité.** Le daemon interne exige
> des capabilities élevées (`SYS_ADMIN`, AppArmor `unconfined`) et l'utilisateur
> a `sudo` sans mot de passe : l'environnement protège contre les erreurs, pas
> contre du code hostile. Lire le
> [modèle de menace](.claude/safe-setup/HACKING.md#modèle-de-menace) avant d'y
> traiter du code non fiable.

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
avant qu'elles n'atteignent la fenêtre de contexte de Claude, avec une réduction
annoncée de 60 à 90 % des tokens.

**Installation** : le binaire précompilé est téléchargé depuis les releases GitHub
pendant le build de l'image (aucune compilation Rust nécessaire), à une version
épinglée et avec vérification du checksum publié par le projet.

Pour changer de version :

```bash
cd .claude/safe-setup
docker compose build --build-arg RTK_VERSION=0.49.0
```

> rtk n'est disponible que sur **amd64** : le projet ne publie pas de binaire
> statique pour linux/arm64. Sur un Mac Apple Silicon, le conteneur démarre
> normalement mais sans compression des sorties — l'entrypoint le signale.

**Configuration** : l'entrypoint exécute `rtk init --global --auto-patch --trust-filters`
au premier démarrage du conteneur, ce qui installe un hook `PreToolUse` dans
`~/.claude/settings.json`. Les commandes lancées par Claude via l'outil Bash sont
alors réécrites de manière transparente (`git status` devient `rtk git status`).
Un fichier témoin `~/.claude/.rtk-initialized` évite de rejouer l'init à chaque
démarrage ; comme il vit dans le volume `claude-history`, la configuration persiste.

**Limite à connaître** : le hook ne s'applique qu'à l'outil **Bash**. Les outils
intégrés de Claude Code (`Read`, `Grep`, `Glob`) ne passent pas par ce hook et ne
sont donc pas compressés. Pour en bénéficier, il faut appeler explicitement
`rtk read`, `rtk grep` ou `rtk find`.

```bash
# Vérifier que le hook est bien installé
rtk init --show

# Voir les statistiques de compression
rtk gain
rtk gain --graph      # graphique ASCII sur 30 jours

# Retrouver une sortie tronquée par un filtre
rtk recall <hash>
```

### codebase-memory-mcp ([graphe de code](https://github.com/DeusData/codebase-memory-mcp))

codebase-memory-mcp indexe le dépôt dans un graphe de connaissances persistant
(fonctions, classes, chaînes d'appel, dépendances) et l'expose à Claude comme
serveur MCP. Cela permet à Claude de répondre à « qui appelle cette fonction ? »
ou « quel est l'impact de ce diff ? » sans relire tout le code, donc à moindre
coût en tokens.

C'est un binaire autonome : **aucune base de données externe, aucune clé API,
aucun service à héberger**. L'index est stocké en SQLite local.

**Installation** : le binaire précompilé est téléchargé pendant le build de
l'image, à une version épinglée et avec vérification du checksum. La variante
`-portable` (liée statiquement) est utilisée, la variante standard exigeant une
glibc plus récente que celle de l'image.

```bash
cd .claude/safe-setup
docker compose build --build-arg CBM_VERSION=0.11.0
```

**Configuration** : le serveur est déclaré dans le fichier [.mcp.json](.mcp.json)
versionné à la racine du projet, donc lisible et partagé avec le dépôt. La variable
`CBM_CACHE_DIR` est positionnée par l'entrypoint sur
`/home/osint/.claude/codebase-memory`, dans le volume persistant : **l'index survit
aux redémarrages du conteneur** et n'est donc à reconstruire qu'après un changement
de code significatif.

```bash
# Vérifier que Claude voit bien le serveur (dans Claude Code)
/mcp

# Première indexation, depuis Claude
# « Index this project »
```

> Le chemin déclaré dans `.mcp.json` est celui du **conteneur**
> (`/usr/local/bin/codebase-memory-mcp`). Pour utiliser aussi le serveur depuis
> l'hôte, installez-y le binaire
> ([install.sh](https://github.com/DeusData/codebase-memory-mcp)) et déclarez-le
> dans votre configuration utilisateur plutôt que dans ce fichier versionné.

Principaux outils exposés : `index_repository`, `search_graph`, `trace_path`,
`get_code_snippet`, `get_architecture`, `search_code`, `query_graph` (Cypher),
`detect_changes` (impact d'un diff git), `manage_adr`.

> Pour que Claude privilégie systématiquement le graphe plutôt que `Grep`/`Read`,
> l'installeur officiel (`install.sh` sans `--skip-config`) sait ajouter des hooks
> `SessionStart` et `PreToolUse` à la configuration de l'agent. Ce dépôt ne les
> installe pas : il se limite à la déclaration MCP versionnée dans `.mcp.json`,
> pour garder une configuration lisible et reproductible.

### PostgreSQL

Un service PostgreSQL 16 accompagne le conteneur de dev. Les variables
`PGHOST=postgres`, `PGUSER=osint`, `PGPASSWORD=osint` et `PGDATABASE=osint` sont
préconfigurées : `psql` sans argument se connecte directement.

```bash
psql
```

Depuis l'hôte, la base est exposée sur le port **5433** (et non 5432, pour
éviter tout conflit avec un PostgreSQL local), lié à `127.0.0.1` uniquement.

### Claude Code

```bash
# Lancer Claude Code
claude
```

## Outils installés

| Outil | Description |
|-------|-------------|
| Python 3.12 | Interpréteur Python |
| click | Construction d'interfaces en ligne de commande |
| omegaconf | Configuration YAML et gestion des secrets |
| pandas | Manipulation de données |
| requests | Requêtes HTTP |
| curl-cffi | Requêtes HTTP avec empreinte TLS de navigateur |
| beautifulsoup4 | Parsing HTML/XML |
| botasaurus | Framework de scraping robuste |
| playwright | Automatisation de navigateur (Chromium préinstallé) |
| telethon | Client Telegram |
| fastapi[standard] | API web et serveur de développement |
| ruff | Linting et formatage (remplace flake8, black, isort) |
| PostgreSQL 16 | Base de données (service séparé, client `psql` dans le conteneur) |
| Docker Engine (DinD) | Daemon Docker isolé dans le conteneur |
| Docker Compose plugin | Commande `docker compose` disponible dans le conteneur |
| Claude Code CLI | Commande `claude` |
| [rtk](https://github.com/rtk-ai/rtk) | Compression des sorties CLI pour réduire la consommation de tokens |
| [codebase-memory-mcp](https://github.com/DeusData/codebase-memory-mcp) | Graphe de connaissances du code, exposé à Claude via MCP |

## Commandes Make

| Commande | Description |
|----------|-------------|
| `make up` | Construire et démarrer les conteneurs |
| `make down` | Arrêter les conteneurs |
| `make shell` | Entrer dans le conteneur de dev |
| `make restart` | Redémarrer |
| `make logs` | Suivre les logs |
| `make status` | État des conteneurs |
| `make clean` | Supprimer conteneurs, images **et volumes** — perte de l'authentification Claude, des historiques et de l'index du graphe |

## Structure du projet

```
.
├── .claude/            # Versionné : visible dans les commits et sur GitHub
│   ├── commands/       # Agents Claude personnalisés
│   ├── safe-setup/     # Configuration Docker
│   ├── tasks/          # Gestion des tâches (todo, done, analyzed, hold-on, abandoned)
│   └── settings.json   # Permissions Claude
├── .mcp.json           # Serveurs MCP du projet (codebase-memory-mcp)
├── CLAUDE.md           # Instructions pour Claude
└── README.md           # Ce fichier
```

Le répertoire `.claude/` est **volontairement versionné** : les agents, la
configuration Docker, les permissions et les tâches font partie du template.
Seuls les secrets et l'état d'exécution sont exclus par [.gitignore](.gitignore) :
`settings.local.json`, les credentials, `projects/`, `todos/`, `statsig/`,
`shell-snapshots/`, `history.jsonl`, `codebase-memory/`, `ide/`, `plugins/`
et le fichier `.env` du setup Docker.

## Agents disponibles

Invoquez ces agents avec `/nom` dans Claude Code :

- `/sceptic` - Propose des tests pour trouver des bugs
- `/rigorous` - Vérifie la cohérence du projet
- `/einstein` - Traque la complexité inutile
- `/paranoid` - Audit de sécurité
- `/grammarian` - Qualité du code et de la documentation
