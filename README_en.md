# Python Development Environment with Claude Code

A sandboxed Docker environment for Python development with Claude Code assistance.

*[Version française](README.md) — [Detailed Docker environment guide](.claude/safe-setup/HACKING_en.md)*

This repo is designed as a **template**: clone it for each new project.
Each clone gets its own Docker volumes (Claude history, Docker images, etc.)
thanks to automatic prefixing by Docker Compose (based on the parent directory name).

Heavily inspired by [Bernard Lambeau](https://github.com/blambeau)'s work, and in
particular [this tutorial](https://www.loom.com/share/ef65c6ebfc35491783ff0a6067447dd4).


## Prerequisites

- Docker and Docker Compose installed
- A Claude Code account (Anthropic API key)

## Quick Start

```bash
# 1. Go to the configuration directory
cd .claude/safe-setup

# 2. Configure your Git identity (optional)
cp .env.example .env
# Edit .env with your info:
# GIT_USER_NAME=Your Name
# GIT_USER_EMAIL=your.email@example.com

# 3. Build and start the containers
make up

# 4. Enter the environment
make shell
```

## Usage

Once inside the container, you are the `osint` user in `/workspace` (the project root).

### Python

```bash
# Python REPL
python

# Run a script
python my_script.py
```

### Linting and Formatting

Linting and formatting are handled by [ruff](https://docs.astral.sh/ruff/),
which replaces flake8, black and isort with a single tool.

```bash
# Check the code
ruff check my_script.py

# Auto-fix what can be fixed
ruff check --fix my_script.py

# Format the code
ruff format my_script.py
```

### Docker (Docker-in-Docker)

A full Docker daemon runs inside the container (DinD mode).
Claude can build images, run `docker compose up` and test Docker configurations
without touching the host's Docker.

> **The container is not a security boundary.** The inner daemon requires raised
> capabilities (`SYS_ADMIN`, AppArmor `unconfined`) and the user has passwordless
> `sudo`: this environment guards against mistakes, not against hostile code.
> Read the [threat model](.claude/safe-setup/HACKING_en.md#threat-model) before
> handling untrusted code in it.

Images and containers created inside the container are persisted via a dedicated Docker volume.

```bash
# Check that the internal Docker daemon is running
docker ps

# Check the Compose version
docker compose version

# Test a docker-compose.yml
docker compose -f my-project/docker-compose.yml up -d
```

### rtk ([Rust Token Killer](https://github.com/rtk-ai/rtk))

rtk is a CLI proxy that compresses command outputs (git, docker, npm, etc.)
before they reach Claude's context window, with a claimed 60 to 90% token reduction.

**Installation**: the prebuilt binary is downloaded from the GitHub releases
during the image build (no Rust compilation needed), at a pinned version and
verified against the checksum published by the project.

To change version:

```bash
cd .claude/safe-setup
docker compose build --build-arg RTK_VERSION=0.49.0
```

> rtk is only available on **amd64**: upstream publishes no static linux/arm64
> binary. On an Apple Silicon Mac the container starts normally but without
> output compression — the entrypoint says so.

**Configuration**: the entrypoint runs `rtk init --global --auto-patch --trust-filters`
on the first container startup, which installs a `PreToolUse` hook into
`~/.claude/settings.json`. Commands Claude runs through the Bash tool are then
rewritten transparently (`git status` becomes `rtk git status`). A marker file
`~/.claude/.rtk-initialized` prevents re-running init on every startup; since it
lives in the `claude-history` volume, the configuration persists.

**Known limitation**: the hook only applies to the **Bash** tool. Claude Code's
built-in tools (`Read`, `Grep`, `Glob`) do not go through it and are therefore not
compressed. To benefit from rtk there, call `rtk read`, `rtk grep` or `rtk find`
explicitly.

```bash
# Verify the hook is installed
rtk init --show

# View compression statistics
rtk gain
rtk gain --graph      # ASCII graph over 30 days

# Recall output elided by a filter
rtk recall <hash>
```

### codebase-memory-mcp ([code graph](https://github.com/DeusData/codebase-memory-mcp))

codebase-memory-mcp indexes the repository into a persistent knowledge graph
(functions, classes, call chains, dependencies) and exposes it to Claude as an MCP
server. This lets Claude answer "who calls this function?" or "what is the impact of
this diff?" without re-reading the whole codebase, which costs far fewer tokens.

It is a self-contained binary: **no external database, no API key, no hosted
service**. The index is stored in a local SQLite database.

**Installation**: the prebuilt binary is downloaded during the image build, at a
pinned version and with checksum verification. The `-portable` (statically
linked) variant is used, as the standard one requires a newer glibc than the
image provides.

```bash
cd .claude/safe-setup
docker compose build --build-arg CBM_VERSION=0.11.0
```

**Configuration**: the server is declared in the [.mcp.json](.mcp.json) file
versioned at the project root, so it ships with the repository. The entrypoint sets
`CBM_CACHE_DIR` to `/home/osint/.claude/codebase-memory`, inside the persistent
volume: **the index survives container restarts** and only needs rebuilding after
significant code changes.

```bash
# Check that Claude sees the server (inside Claude Code)
/mcp

# First indexing, from Claude
# "Index this project"
```

> The path declared in `.mcp.json` is the **container** one
> (`/usr/local/bin/codebase-memory-mcp`). To use the server from the host as well,
> install the binary there
> ([install.sh](https://github.com/DeusData/codebase-memory-mcp)) and declare it in
> your user configuration rather than in this versioned file.

Main exposed tools: `index_repository`, `search_graph`, `trace_path`,
`get_code_snippet`, `get_architecture`, `search_code`, `query_graph` (Cypher),
`detect_changes` (git diff impact), `manage_adr`.

> To make Claude reach for the graph instead of `Grep`/`Read`, the official
> installer (`install.sh` without `--skip-config`) can add `SessionStart` and
> `PreToolUse` hooks to the agent configuration. This repo does not install them:
> it sticks to the versioned MCP declaration in `.mcp.json`, to keep the
> configuration readable and reproducible.

### PostgreSQL

A PostgreSQL 16 service runs alongside the dev container. The `PGHOST=postgres`,
`PGUSER=osint`, `PGPASSWORD=osint` and `PGDATABASE=osint` variables are
preconfigured, so bare `psql` connects straight away.

```bash
psql
```

From the host, the database is exposed on port **5433** (not 5432, to avoid
clashing with a local PostgreSQL), bound to `127.0.0.1` only.

### Claude Code

```bash
# Launch Claude Code
claude
```

## Installed Tools

| Tool | Description |
|------|-------------|
| Python 3.12 | Python interpreter |
| click | Command-line interface building |
| omegaconf | YAML configuration and secrets management |
| pandas | Data manipulation |
| requests | HTTP requests |
| curl-cffi | HTTP requests with browser TLS fingerprint |
| beautifulsoup4 | HTML/XML parsing |
| botasaurus | Robust scraping framework |
| playwright | Browser automation (Chromium preinstalled) |
| telethon | Telegram client |
| fastapi[standard] | Web API and development server |
| ruff | Linting and formatting (replaces flake8, black, isort) |
| PostgreSQL 16 | Database (separate service, `psql` client in the container) |
| Docker Engine (DinD) | Isolated Docker daemon inside the container |
| Docker Compose plugin | `docker compose` command available inside the container |
| Claude Code CLI | `claude` command |
| [rtk](https://github.com/rtk-ai/rtk) | CLI output compression to reduce token consumption |
| [codebase-memory-mcp](https://github.com/DeusData/codebase-memory-mcp) | Code knowledge graph, exposed to Claude over MCP |

## Make Commands

| Command | Description |
|---------|-------------|
| `make up` | Build and start the containers |
| `make down` | Stop the containers |
| `make shell` | Enter the dev container |
| `make restart` | Restart |
| `make logs` | Follow the logs |
| `make status` | Containers status |
| `make clean` | Remove containers, images **and volumes** — loses the Claude authentication, the histories and the graph index |

## Project Structure

```
.
├── .claude/            # Versioned: visible in commits and on GitHub
│   ├── commands/       # Custom Claude agents
│   ├── safe-setup/     # Docker configuration
│   ├── tasks/          # Task management (todo, done, analyzed, hold-on, abandoned)
│   └── settings.json   # Claude permissions
├── .mcp.json           # Project MCP servers (codebase-memory-mcp)
├── CLAUDE.md           # Instructions for Claude
└── README.md           # This file
```

The `.claude/` directory is **deliberately versioned**: the agents, Docker setup,
permissions and tasks are part of the template. Only secrets and runtime state are
excluded by [.gitignore](.gitignore): `settings.local.json`, credentials,
`projects/`, `todos/`, `statsig/`, `shell-snapshots/`, `history.jsonl`,
`codebase-memory/`, `ide/`, `plugins/` and the Docker setup `.env`.

## Available Agents

Invoke these agents with `/name` in Claude Code:

- `/sceptic` - Proposes tests to find bugs
- `/rigorous` - Checks project consistency
- `/einstein` - Tracks unnecessary complexity
- `/paranoid` - Security audit
- `/grammarian` - Code and documentation quality
