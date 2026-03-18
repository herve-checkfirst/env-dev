# Python Development Environment with Claude Code

A sandboxed Docker environment for Python development with Claude Code assistance.

This repo is designed as a **template**: clone it for each new project.
Each clone gets its own Docker volumes (Claude history, Docker images, etc.)
thanks to automatic prefixing by Docker Compose (based on the parent directory name).

Heavily inspired by Bernard Lambeau https://github.com/blambeau, and in particular this tutorial:

https://www.loom.com/share/ef65c6ebfc35491783ff0a6067447dd4


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

# 3. Build and start the container
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

# Jupyter Notebook (accessible at http://localhost:8888)
jupyter notebook --ip=0.0.0.0

# Run a script
python my_script.py
```

### Linting and Formatting

```bash
# Check style with flake8
flake8 my_script.py

# Format with black
black my_script.py

# Sort imports
isort my_script.py
```

### Docker (Docker-in-Docker)

A full Docker daemon runs inside the container (DinD mode).
Claude can build images, run `docker compose up` and test Docker
configurations in complete isolation, without affecting the host.

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
before they reach Claude's context window. 60 to 90% token reduction.

The auto-rewrite hook is activated automatically on the first container startup.
Commands are transparently rewritten (`git status` becomes `rtk git status`).

```bash
# View compression statistics
rtk gain
```

### Claude Code

```bash
# Launch Claude Code
claude
```

## Installed Tools

| Tool | Description |
|------|-------------|
| Python 3.12 | Python interpreter |
| pandas | Data manipulation |
| requests | HTTP requests |
| beautifulsoup4 | HTML/XML parsing |
| jupyter | Interactive notebooks |
| black | Code formatting |
| flake8 | Linting |
| isort | Import sorting |
| Docker Engine (DinD) | Isolated Docker daemon inside the container |
| Docker Compose plugin | `docker compose` command available inside the container |
| [rtk](https://github.com/rtk-ai/rtk) | CLI output compression to reduce token consumption |

## Make Commands

| Command | Description |
|---------|-------------|
| `make up` | Build and start the container |
| `make down` | Stop the container |
| `make shell` | Enter the container |
| `make restart` | Restart |
| `make logs` | View logs |
| `make status` | Container status |
| `make clean` | Remove containers and images |

## Project Structure

```
.
├── .claude/
│   ├── commands/       # Custom Claude agents
│   ├── safe-setup/     # Docker configuration
│   ├── tasks/          # Task management
│   └── settings.json   # Claude permissions
├── CLAUDE.md           # Instructions for Claude
└── README.md           # This file
```

## Available Agents

Invoke these agents with `/name` in Claude Code:

- `/sceptic` - Proposes tests to find bugs
- `/rigorous` - Checks project consistency
- `/einstein` - Tracks unnecessary complexity
- `/paranoid` - Security audit
- `/grammarian` - Code and documentation quality
