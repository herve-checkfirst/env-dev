# Environnement de développement avec Claude Code

*[English version](HACKING_en.md) — [README du projet](../../README.md)*

Ce setup Docker fournit un environnement sandboxé avec tous les outils nécessaires :
- Python 3.12 avec pandas, requests, BeautifulSoup, botasaurus, playwright,
  click, omegaconf, telethon, fastapi, curl-cffi
- ruff pour le linting et le formatage
- Docker-in-Docker (daemon isolé dans le conteneur)
- PostgreSQL 16
- Claude Code CLI
- rtk (compression des sorties CLI)
- codebase-memory-mcp (graphe de connaissances du code, exposé via MCP)

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

- **Credentials et historique Claude** : volume Docker `claude-history`, persiste entre les redémarrages. L'authentification ne se fait qu'une seule fois.
- **Historique Bash** : volume Docker `bash-history`
- **Images et conteneurs Docker internes** : volume Docker `docker-data`, les images construites par Claude sont conservées entre les sessions.
- **Index du graphe de code** : `/home/osint/.claude/codebase-memory` (dans le volume `claude-history`), l'index de codebase-memory-mcp n'est donc pas à reconstruire à chaque démarrage.
- **Configuration rtk** : le hook vit dans `/home/osint/.claude/settings.json` (même volume), donc l'init ne se rejoue pas à chaque démarrage.
- **Configuration Git** : définie automatiquement via les variables `GIT_USER_NAME` et `GIT_USER_EMAIL`

## Modèle de menace

À lire avant de confier du code non fiable à cet environnement.

**Ce que le conteneur protège :**
- l'hôte contre les dégâts *accidentels* (un `rm` malheureux touche `/workspace`,
  pas votre `$HOME`) ;
- l'isolation des dépendances Python entre projets ;
- votre Docker hôte : les images et conteneurs construits par Claude restent
  dans le daemon interne.

**Ce que le conteneur ne protège pas.** Ce n'est **pas** une frontière de
sécurité face à du code *hostile* :
- `SYS_ADMIN` et AppArmor `unconfined` sont nécessaires au daemon Docker interne
  et suffisent à s'évader du conteneur ;
- l'utilisateur `osint` a `sudo` sans mot de passe ;
- la racine du dépôt est montée en écriture sur `/workspace`, `.git` compris ;
- les permissions Claude autorisent `bash`, `curl` et `WebFetch` sans
  confirmation (voir `.claude/settings.json`).

Concrètement : une dépendance PyPI malveillante ou une injection d'instructions
via une page web peut atteindre l'hôte. Sur macOS et Windows, Docker Desktop
ajoute une VM intermédiaire qui limite les dégâts ; **sur un hôte Linux, une
évasion donne root sur l'hôte**. Ne pas exécuter ce template sur un serveur
partagé ou en CI sans durcissement supplémentaire.

Pour une isolation réelle, remplacer le DinD par [Sysbox](https://github.com/nestybox/sysbox)
ou un `dockerd` rootless, qui fournissent Docker-in-Docker sans capability
privilégiée.

## Docker-in-Docker

Le conteneur embarque un daemon Docker complet (mode DinD). Claude peut :
- Construire des images (`docker build`)
- Lancer des services (`docker compose up`)
- Tester des configurations Docker de manière isolée

Les conteneurs lancés par Claude tournent **dans** le conteneur de dev, et non
dans le daemon Docker de l'hôte.

Le daemon interne exige `cap_add: SYS_ADMIN` et `security_opt:
apparmor:unconfined` (voir `docker-compose.yml`). C'est plus étroit que le
`privileged: true` utilisé auparavant, qui accordait en plus toutes les autres
capabilities et l'accès aux périphériques de l'hôte — mais cela reste
incompatible avec une isolation stricte, cf. « Modèle de menace » ci-dessus.

## rtk (Rust Token Killer)

rtk compresse automatiquement les sorties de commandes CLI avant qu'elles n'atteignent
la fenêtre de contexte de Claude, avec une réduction annoncée de 60 à 90 % des
tokens.

Le binaire précompilé est installé pendant le build de l'image depuis les
releases GitHub du projet, **à une version épinglée** (`ARG RTK_VERSION`) et avec
vérification du checksum publié :

```bash
docker compose build --build-arg RTK_VERSION=0.49.0
```

> **Disponible sur amd64 uniquement.** Le projet ne publie pas de binaire
> statique pour linux/arm64 (seule une variante liée à une glibc plus récente
> que celle de l'image). Sur un Mac Apple Silicon, le conteneur démarre sans rtk
> et l'entrypoint l'indique.

L'entrypoint installe ensuite le hook s'il n'est pas déjà en place :

```bash
rtk init --global --auto-patch --trust-filters
```

La présence du hook est vérifiée par `rtk init --show`, et non par un fichier
témoin : `/home/osint/.claude` est un volume qui survit aux reconstructions
d'image, un témoin pourrait donc affirmer la présence d'un hook disparu.

Les deux options rendent l'init non interactive, mais elles n'ont pas le même
poids :
- `--auto-patch` répond au prompt de modification de `settings.json` ;
- `--trust-filters` accepte **sans revue** les filtres personnalisés détectés.
  Ces filtres transforment la sortie des commandes que Claude observe : c'est un
  contrôle de sécurité court-circuité au profit d'un démarrage automatique. Pour
  le conserver, retirer ce flag de `entrypoint.sh` et valider les filtres
  manuellement au premier `make shell`.

Si l'init échoue, l'entrypoint avertit et continue : le conteneur reste
utilisable, simplement sans compression.

```bash
# Vérifier l'installation du hook
rtk init --show

# Voir les statistiques de compression
rtk gain
rtk gain --graph      # graphique ASCII sur 30 jours

# Retrouver une sortie tronquée par un filtre
rtk recall <hash>

# Relancer l'init manuellement si besoin
rtk init --global --auto-patch --trust-filters
```

**Limite** : le hook ne couvre que l'outil Bash. Les outils internes de Claude Code
(`Read`, `Grep`, `Glob`) ne sont pas compressés ; utiliser `rtk read`, `rtk grep`,
`rtk find` pour en bénéficier.

## codebase-memory-mcp (graphe de code)

[codebase-memory-mcp](https://github.com/DeusData/codebase-memory-mcp) indexe le
dépôt dans un graphe persistant et l'expose à Claude comme serveur MCP. Claude peut
alors répondre à des questions structurelles (« qui appelle cette fonction ? »,
« quel est le rayon d'impact de ce diff ? ») sans relire le code, ce qui économise
beaucoup de tokens.

Binaire autonome : ni base de données externe, ni clé API, ni service à héberger.
L'index est stocké dans une base SQLite locale.

**Installation** : binaire précompilé téléchargé pendant le build dans
`/usr/local/bin/codebase-memory-mcp`, **à une version épinglée**
(`ARG CBM_VERSION`) et avec vérification du checksum :

```bash
docker compose build --build-arg CBM_VERSION=0.11.0
```

La variante **`-portable`** est utilisée : le binaire linux standard est lié
dynamiquement à la glibc 2.38+, alors que l'image (Debian bookworm) fournit la
2.36 — il ne démarrerait pas. C'est aussi le choix que fait l'installeur
officiel du projet sous Linux.

**Déclaration MCP** : dans le fichier `.mcp.json` versionné à la racine du dépôt,
et non via l'auto-configuration de l'installeur. La config est ainsi lisible,
partagée avec le dépôt et reproductible.

```json
{
  "mcpServers": {
    "codebase-memory-mcp": {
      "command": "/usr/local/bin/codebase-memory-mcp",
      "args": [],
      "env": {
        "CBM_CACHE_DIR": "/home/osint/.claude/codebase-memory"
      }
    }
  }
}
```

**Stockage** : `CBM_CACHE_DIR=/home/osint/.claude/codebase-memory`, défini comme
`ENV` dans le Dockerfile — et non exporté par l'entrypoint, car
`docker compose exec` (donc `make shell`) ne passe pas par l'entrypoint et
n'hériterait pas de la variable. Le chemin est aussi déclaré dans `.mcp.json`.

```bash
# Le binaire est bien installé
codebase-memory-mcp --version

# Le serveur répond au handshake MCP (doit renvoyer serverInfo en JSON)
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"t","version":"1"}}}' \
  | codebase-memory-mcp

# Dans Claude Code : vérifier que le serveur est vu, avec ses outils
/mcp
```

Le serveur sort dès la fermeture de stdin : c'est le comportement MCP normal, pas
une erreur.

Première utilisation : demander à Claude « Index this project » (outil
`index_repository`). Ensuite sont disponibles `search_graph`, `trace_path`,
`get_code_snippet`, `get_architecture`, `search_code`, `query_graph`,
`detect_changes` et `manage_adr`.

Variables d'environnement optionnelles utiles : `CBM_WORKERS` (parallélisme
d'indexation, pratique en conteneur où la détection CPU est parfois fausse),
`CBM_MEM_BUDGET_MB` (plafond mémoire du graphe), `CBM_LOG_LEVEL`.

## Dans le conteneur

Vous êtes l'utilisateur `osint` dans `/workspace` (la racine du projet).

```bash
# Lancer Claude Code
claude

# Se connecter à PostgreSQL
psql
```

PostgreSQL est pré-configuré via `PGHOST=postgres`, `PGUSER=osint`,
`PGPASSWORD=osint` et `PGDATABASE=osint` : `psql` sans argument se connecte
directement.

Depuis l'hôte, la base est exposée sur le port **5433** (et non 5432, pour
éviter tout conflit avec un PostgreSQL local), lié à `127.0.0.1` uniquement.
Les identifiants sont triviaux et destinés au développement local : ne pas
publier ce port sur un réseau.

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
