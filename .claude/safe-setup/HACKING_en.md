# Development Environment with Claude Code

This Docker setup provides a sandboxed environment with all necessary tools:
- Python 3.12 with pandas, requests, BeautifulSoup, botasaurus, playwright
- Docker-in-Docker (isolated daemon inside the container)
- PostgreSQL
- Claude Code CLI
- rtk (CLI output compression)

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
- **Git configuration**: Automatically set via `GIT_USER_NAME` and `GIT_USER_EMAIL` variables

## Docker-in-Docker

The container runs a full Docker daemon (DinD mode). Claude can:
- Build images (`docker build`)
- Start services (`docker compose up`)
- Test Docker configurations in isolation

Containers launched by Claude run **inside** the dev container, not on the host.
The `privileged` mode is required for the internal Docker daemon to function.

## rtk (Rust Token Killer)

rtk automatically compresses CLI command outputs before they reach Claude's context
window (60-90% token reduction).

The auto-rewrite hook is activated automatically on first startup.

```bash
# View compression statistics
rtk gain
```

## Inside the Container

You are the `osint` user in `/workspace` (the project root).

```bash
# Launch Claude Code
claude

# Connect to PostgreSQL
psql
```

PostgreSQL is pre-configured via environment variables.

## Make Commands

| Command | Description |
|---------|-------------|
| `make up` | Build and start the containers |
| `make down` | Stop the containers |
| `make shell` | Enter the dev container |
| `make restart` | Restart |
| `make logs` | Follow logs |
| `make status` | Container status |
| `make clean` | Remove containers and images |
