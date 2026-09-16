# Development Environment with Claude Code

*[Version française](HACKING.md) — [Project README](../../README_en.md)*

This Docker setup provides a sandboxed environment with all necessary tools:
- Python 3.12 with pandas, requests, BeautifulSoup, botasaurus, playwright,
  click, omegaconf, telethon, fastapi, curl-cffi
- ruff for linting and formatting
- Docker-in-Docker (isolated daemon inside the container)
- PostgreSQL 16
- Claude Code CLI
- rtk (CLI output compression)
- codebase-memory-mcp (code knowledge graph, exposed over MCP)

## Prerequisites

1. Docker and Docker Compose installed on the host
2. A Claude Code account (Anthropic API key)

## Getting Started

```bash
cd .claude/safe-setup

# Create the .env file from the template
cp .env.example .env

# Edit .env with your Git identity
# GIT_USER_NAME=Your Name
# GIT_USER_EMAIL=your.email@example.com

# Build and start the containers
make up

# Enter the environment
make shell
```

## Persistent Data

- **Claude credentials and history**: Docker volume `claude-history`, persists across restarts. Authentication is required only once.
- **Bash history**: Docker volume `bash-history`
- **Internal Docker images and containers**: Docker volume `docker-data`, images built by Claude are preserved between sessions.
- **Code graph index**: `/home/osint/.claude/codebase-memory` (inside the `claude-history` volume), so codebase-memory-mcp's index does not need rebuilding on every startup.
- **rtk configuration**: the hook lives in `/home/osint/.claude/settings.json` (same volume), so the init does not re-run on every startup.
- **Git configuration**: Automatically set via `GIT_USER_NAME` and `GIT_USER_EMAIL` variables

## Threat model

Read this before letting this environment handle untrusted code.

**What the container protects:**
- the host against *accidental* damage (a stray `rm` hits `/workspace`, not your
  `$HOME`);
- Python dependency isolation between projects;
- your host Docker: images and containers Claude builds stay in the inner daemon.

**What it does not protect.** This is **not** a security boundary against
*hostile* code:
- `SYS_ADMIN` and AppArmor `unconfined` are required by the inner Docker daemon
  and are enough to escape the container;
- the `osint` user has passwordless `sudo`;
- the repository root is mounted read-write at `/workspace`, `.git` included;
- Claude's permissions allow `bash`, `curl` and `WebFetch` without confirmation
  (see `.claude/settings.json`).

In practice: a malicious PyPI dependency or a prompt injection from a web page
can reach the host. On macOS and Windows, Docker Desktop's intermediate VM
limits the damage; **on a Linux host, an escape means root on the host**. Do not
run this template on a shared server or in CI without further hardening.

For real isolation, replace DinD with [Sysbox](https://github.com/nestybox/sysbox)
or a rootless `dockerd`, which provide Docker-in-Docker without a privileged
capability.

## Docker-in-Docker

The container runs a full Docker daemon (DinD mode). Claude can:
- Build images (`docker build`)
- Start services (`docker compose up`)
- Test Docker configurations in isolation

Containers launched by Claude run **inside** the dev container, not in the host's
Docker daemon.

The inner daemon requires `cap_add: SYS_ADMIN` and `security_opt:
apparmor:unconfined` (see `docker-compose.yml`). That is narrower than the
`privileged: true` used previously, which also granted every other capability
and host device access — but it is still incompatible with strict isolation, see
"Threat model" above.

## rtk (Rust Token Killer)

rtk automatically compresses CLI command outputs before they reach Claude's context
window, with a claimed 60 to 90% token reduction.

The prebuilt binary is installed during the image build from the project's GitHub
releases, **at a pinned version** (`ARG RTK_VERSION`) and verified against the
published checksum:

```bash
docker compose build --build-arg RTK_VERSION=0.49.0
```

> **amd64 only.** Upstream publishes no static linux/arm64 binary (only a variant
> linked against a newer glibc than the image provides). On an Apple Silicon Mac
> the container starts without rtk and the entrypoint says so.

The entrypoint then installs the hook if it is not already in place:

```bash
rtk init --global --auto-patch --trust-filters
```

Hook presence is probed with `rtk init --show` rather than a marker file:
`/home/osint/.claude` is a volume that outlives image rebuilds, so a marker could
claim a hook that is no longer there.

Both options make the init non-interactive, but they do not carry the same weight:
- `--auto-patch` answers the `settings.json` patching prompt;
- `--trust-filters` accepts detected custom filters **without review**. Those
  filters transform the command output Claude sees, so this is a safety check
  traded away for an unattended start. To keep it, drop the flag from
  `entrypoint.sh` and vet the filters manually on the first `make shell`.

If the init fails, the entrypoint warns and continues: the container stays usable,
just without compression.

```bash
# Verify the hook installation
rtk init --show

# View compression statistics
rtk gain
rtk gain --graph      # ASCII graph over 30 days

# Recall output elided by a filter
rtk recall <hash>

# Re-run the init manually if needed
rtk init --global --auto-patch --trust-filters
```

**Limitation**: the hook only covers the Bash tool. Claude Code's built-in tools
(`Read`, `Grep`, `Glob`) are not compressed; use `rtk read`, `rtk grep`, `rtk find`
to benefit from it there.

## codebase-memory-mcp (code graph)

[codebase-memory-mcp](https://github.com/DeusData/codebase-memory-mcp) indexes the
repository into a persistent graph and exposes it to Claude as an MCP server. Claude
can then answer structural questions ("who calls this function?", "what is the blast
radius of this diff?") without re-reading the code, saving a lot of tokens.

Self-contained binary: no external database, no API key, no hosted service. The index
is stored in a local SQLite database.

**Installation**: prebuilt binary downloaded during the build into
`/usr/local/bin/codebase-memory-mcp`, **at a pinned version** (`ARG CBM_VERSION`)
and with checksum verification:

```bash
docker compose build --build-arg CBM_VERSION=0.11.0
```

The **`-portable`** variant is used: the standard linux binary dynamically links
glibc 2.38+, while the image (Debian bookworm) provides 2.36 — it would not run.
Upstream's own installer makes the same choice on Linux.

**MCP declaration**: in the `.mcp.json` file versioned at the repository root, rather
than through the installer's auto-configuration. The config is therefore readable,
shipped with the repo and reproducible.

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

**Storage**: `CBM_CACHE_DIR=/home/osint/.claude/codebase-memory`, set as an `ENV`
in the Dockerfile rather than exported by the entrypoint, because
`docker compose exec` (so `make shell`) never runs the entrypoint and would not
inherit it. The path is declared in `.mcp.json` too.

```bash
# The binary is installed
codebase-memory-mcp --version

# The server answers the MCP handshake (should return serverInfo as JSON)
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"t","version":"1"}}}' \
  | codebase-memory-mcp

# In Claude Code: check the server is seen, with its tools
/mcp
```

The server exits as soon as stdin closes: that is normal MCP behavior, not an
error.

First use: ask Claude "Index this project" (the `index_repository` tool). Then
`search_graph`, `trace_path`, `get_code_snippet`, `get_architecture`,
`search_code`, `query_graph`, `detect_changes` and `manage_adr` are available.

Useful optional environment variables: `CBM_WORKERS` (indexing parallelism, handy in
containers where CPU detection is unreliable), `CBM_MEM_BUDGET_MB` (graph memory
cap), `CBM_LOG_LEVEL`.

## Inside the Container

You are the `osint` user in `/workspace` (the project root).

```bash
# Launch Claude Code
claude

# Connect to PostgreSQL
psql
```

PostgreSQL is pre-configured via `PGHOST=postgres`, `PGUSER=osint`,
`PGPASSWORD=osint` and `PGDATABASE=osint`, so bare `psql` connects straight away.

From the host, the database is exposed on port **5433** (not 5432, to avoid
clashing with a local PostgreSQL), bound to `127.0.0.1` only. The credentials are
trivial and meant for local development: do not publish this port on a network.

## Make Commands

| Command | Description |
|---------|-------------|
| `make up` | Build and start the containers |
| `make down` | Stop the containers |
| `make shell` | Enter the dev container |
| `make restart` | Restart |
| `make logs` | Follow logs |
| `make status` | Container status |
| `make clean` | Remove containers, images **and volumes** — loses the Claude authentication, the histories and the graph index |
