# Resynchroniser la doc, intégrer codebase-memory-mcp, corriger la revue

Statut : terminé (2026-09-16)

## Contexte

Reprise du projet. La documentation avait divergé du Dockerfile depuis le
passage à ruff (commit 5c87229), et l'outillage d'économie de tokens n'était que
partiellement en place. Une revue complète par les cinq agents du projet
(`/sceptic`, `/rigorous`, `/einstein`, `/paranoid`, `/grammarian`) a ensuite
révélé un bug bloquant et plusieurs décalages.

## Décalages doc/image corrigés

- README et HACKING citaient `flake8`, `isort`, `black`, `jupyter` : aucun n'est
  installé. Sections linting réécrites autour de ruff, tableaux d'outils alignés
  sur le Dockerfile réel.
- `CLAUDE.md` recommandait encore `black/pep8` — angle mort de la première passe,
  relevé par `/rigorous` et `/grammarian`. Section « Python Best Practices »
  réécrite (+ coquilles `fo`, `secrets managements`).
- `.claude/tasks/` créée (documentée mais inexistante).
- `.DS_Store` supprimés, Project Overview rempli.
- `/grammarian` manquait dans `CLAUDE.md` ; descriptions d'agents alignées sur le
  frontmatter des fichiers, désigné comme source canonique.

## Bug bloquant corrigé (trouvé par /sceptic)

**Le build aurait échoué sur toute architecture.** Le binaire
`codebase-memory-mcp-linux-amd64` est lié dynamiquement à la glibc 2.38, alors
que l'image (Debian bookworm) fournit la 2.36. Vérifié sur pièces :
`strings` révèle `GLIBC_2.38`, et l'`install.sh` livré dans l'archive amont
choisit toujours la variante `-portable` sous Linux pour cette raison.
→ bascule sur `-portable`, statiquement liée (`file` confirme
`statically linked`).

Corollaire : rtk n'a **pas** de binaire statique pour arm64 (seul un `gnu`
exigeant la glibc 2.39). Sur Apple Silicon, rtk n'est donc plus installé et
l'entrypoint le signale, au lieu de casser le build.

## Autres corrections du Dockerfile

- **Versions épinglées** (`RTK_VERSION=0.49.0`, `CBM_VERSION=0.11.0`) : deux
  builds successifs produisent désormais la même image. `ARG RTK_VERSION` était
  par ailleurs inatteignable (aucun bloc `args:` dans compose) — relevé par
  `/einstein`.
- **Vérification des checksums** contre le `checksums.txt` de chaque release,
  que le setup ignorait alors que les installeurs amont la rendent obligatoire.
- **`curl -o` au lieu de `curl | tar`** : un 404 passait silencieusement, car
  `set -eux` ne couvre pas `pipefail` et le `RUN` s'exécute sous dash. Testé :
  le pipeline renvoyait 0 sur un 404, il renvoie maintenant 56.
- `TARGETARCH` vide refusé explicitement au lieu de retomber en silence sur
  amd64 (ce qui produisait une image amd64 sur un hôte arm64).
- Extraction durcie : `--no-same-owner --no-same-permissions`.

## Sécurité (revue /paranoid)

- **`privileged: true` remplacé** par `cap_add: SYS_ADMIN` +
  `security_opt: apparmor:unconfined` : le strict nécessaire au DinD, au lieu de
  toutes les capabilities et de l'accès aux périphériques de l'hôte.
  **À valider au build** (voir la tâche `todo/build-validation-env-docker.md`).
- **Modèle de menace documenté** (FR et EN) : le README promettait un
  environnement « sandboxé » et HACKING affirmait « pas sur l'hôte ». C'était
  faux et c'était le risque le plus concret, puisque cela conduit à y exécuter du
  code non fiable. La doc distingue maintenant ce que le conteneur protège
  (erreurs accidentelles, dépendances, Docker hôte) de ce qu'il ne protège pas
  (code hostile), avec la nuance Docker Desktop macOS vs hôte Linux.
- **Socket Docker en `660 root:docker`** au lieu de `666` (osint est dans le
  groupe docker, le `chmod 666` était inutile et donnait root à tout processus).
- **Postgres lié à `127.0.0.1`** : les identifiants triviaux `osint/osint`
  n'étaient pas censés être joignables depuis le réseau local.
- **Permissions Claude resserrées** : `Bash(bash:*)` retiré (il rendait la
  deny-list contournable par `bash -c`), `curl`/`wget`/`ssh`/`sudo` en deny,
  `WebFetch(domain:*)` remplacé par une liste de domaines, ajout des outils
  réellement présents (`ruff`, `rtk`, `psql`, `docker`) et retrait de `jupyter`.
- **`.gitignore` complété** : `.claude/.claude.json`, `mcp.json`, `ide/`,
  `plugins/`, `*.local.json`. Règle `.env` dupliquée supprimée (une seule source).
- **Refs Git étrangères supprimées** : le dépôt contenait `origin/type-checking`
  et les tags `v0.9.1`→`v0.9.5` d'un autre projet (un site Astro), héritées d'un
  `.git` réutilisé. Le dépôt étant **public**, un `git push --tags` aurait publié
  l'historique d'un projet tiers. Aucun secret dedans, et le remote ne contenait
  que `main`. Objets purgés, `git fsck` propre.

## Bugs fonctionnels corrigés

- **`CBM_CACHE_DIR` n'atteignait pas le serveur MCP** : il était seulement
  exporté par l'entrypoint, or `docker compose exec` (donc `make shell`) ne passe
  pas par l'entrypoint. L'index se serait reconstruit à chaque fois, alors que la
  doc affirmait le contraire. → `ENV` dans le Dockerfile + bloc `env` dans
  `.mcp.json`.
- **Témoin `.rtk-initialized` désynchronisable** : `~/.claude` est un volume qui
  survit aux reconstructions d'image, le témoin pouvait donc affirmer la présence
  d'un hook disparu. → sonde d'état réelle via `rtk init --show | grep PreToolUse`.
- **Timeout `dockerd` silencieux** : la boucle d'attente ne distinguait pas le
  succès du timeout, l'échec ne se manifestait que plus tard par un message
  opaque. → avertissement explicite renvoyant vers `/var/log/dockerd.log`.

## Cohérence documentaire (revue /rigorous)

- Port **5433** et variables `PG*` documentés : ils ne l'étaient nulle part.
- `make clean` supprime aussi les **volumes** (auth Claude, historiques, index) :
  les quatre docs l'omettaient.
- « le conteneur » → « les conteneurs » : compose définit `dev` **et** `postgres`.
- Liste des outils MCP unifiée sur les 9 outils (les trois docs en donnaient
  trois versions différentes, et HACKING omettait `index_repository` tout en le
  décrivant en prose).
- Liens croisés FR↔EN et README↔HACKING : les quatre documents étaient isolés.
- Accents de l'en-tête du README corrigés, espaces insécables françaises,
  vocabulaire normalisé. Miroir FR/EN vérifié : 37/37 et 25/25 titres.

## Vérifications effectuées (sans build)

- Dépendances glibc mesurées avec `file` et `strings` sur les binaires réels ;
  variantes `-portable` confirmées statiques.
- Assets des deux releases énumérés via l'API GitHub.
- Fonction `fetch` exécutée contre les vrais serveurs : checksum `OK`,
  extraction réussie ; un tag inexistant échoue avec le code 56.
- Format des `checksums.txt` inspecté : l'`awk` teste l'égalité exacte, donc ne
  confond pas le binaire avec la variante `-ui-` qui partage un suffixe.
- `bash -n` et `sh -n` (dash, shell réel du `RUN`) sur le `RUN` et l'entrypoint.
- JSON et YAML validés ; `git check-ignore` : rien d'utile ignoré.
- `git fsck` propre après purge des refs étrangères.

## Reste à faire

`make up` n'a jamais été lancé : voir `todo/build-validation-env-docker.md`.
Le point sensible est le remplacement de `privileged: true`.
