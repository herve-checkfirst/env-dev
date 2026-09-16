# Valider le build de l'image Docker

Statut : à faire

## Contexte

La resynchronisation doc/image et l'intégration de codebase-memory-mcp sont
terminées et revues par les cinq agents du projet. Le Dockerfile a été corrigé
d'un bug bloquant trouvé par `/sceptic` (voir ci-dessous), mais **l'image n'a
jamais été construite** : Docker n'était pas démarré sur l'hôte.

## À exécuter

```bash
cd .claude/safe-setup
make up
make shell
```

Puis, dans le conteneur :

```bash
codebase-memory-mcp --version     # doit afficher 0.11.0
rtk init --show                   # doit montrer le hook PreToolUse (amd64 seulement)
rtk gain
ruff --version
psql -c 'select 1'
docker ps                         # le daemon interne doit répondre
claude                            # puis /mcp : le serveur doit être listé
```

## Points à surveiller en particulier

1. **`cap_add: SYS_ADMIN` remplace `privileged: true`.** C'est le changement le
   plus risqué : le daemon Docker interne peut exiger davantage (accès à
   `/dev`, montages). Si `docker ps` échoue dans le conteneur, consulter
   `/var/log/dockerd.log`. Pistes : ajouter `cap_add: NET_ADMIN`,
   `security_opt: seccomp:unconfined`, ou revenir à `privileged: true` en
   assumant le modèle de menace désormais documenté.
2. **Taille de l'image.** La variante `-portable` de codebase-memory-mcp fait
   ~290 Mo non strippée. Vérifier `docker images` et envisager un `strip`.
3. **arm64.** Sur Mac Apple Silicon, rtk n'est pas installé (aucun binaire
   statique publié en amont). Vérifier que l'entrypoint affiche bien la note et
   que le conteneur reste fonctionnel.
4. **Persistance de l'index.** Après un `make down && make up`, vérifier que
   `/home/osint/.claude/codebase-memory` contient toujours l'index.

## Si le build échoue

Le `RUN` d'installation des binaires est conçu pour échouer franchement :
checksum vérifié, `curl -o` séparé du `tar` (un 404 renvoie désormais un code
d'erreur au lieu de passer silencieusement), `TARGETARCH` vide refusé.
Le message d'erreur doit donc être explicite.
