# Claude Development Guide

This document provides instructions for AI assistants (like Claude) working on this project.

Always respond in French.

## Project Overview

This repository is a **template** for a sandboxed Python development environment
driven by Claude Code. It contains no application code: only the Docker setup,
the custom agents, the permissions and the task workflow. Clone it for each new
project, then replace this section with the actual project description.

## Design Principles

- Keep code simple and readable
- Document important decisions
- Test before committing

## Development Environment

A sandboxed Docker environment is available in `.claude/safe-setup/`:
- Python 3.12 with pandas, requests, BeautifulSoup, botasaurus, playwright,
  click, omegaconf, telethon, fastapi, curl-cffi, ruff
- Docker-in-Docker, so Docker configurations can be tested without touching the
  host's Docker daemon. **The container is not a security boundary**: it needs
  raised capabilities and grants passwordless `sudo`. See the threat model in
  `.claude/safe-setup/HACKING.md` before handling untrusted code.
- PostgreSQL 16 as a separate service
- User `osint` with sudo access
- Persistent Claude history, rtk configuration and code graph index

Run it with `cd .claude/safe-setup && make up && make shell`.
See `.claude/safe-setup/HACKING.md` for setup instructions.

### Token-saving tooling

Two tools are installed to keep context usage low. Both are configured
automatically; see `HACKING.md` for details and troubleshooting.

- **rtk** compresses Bash command output before it reaches the context window.
  The hook is installed by the entrypoint on first startup. It only covers the
  Bash tool: use `rtk read`, `rtk grep`, `rtk find` rather than piping large
  outputs by hand.
- **codebase-memory-mcp** exposes a persistent code knowledge graph over MCP,
  declared in the versioned `.mcp.json`. **Prefer it over `Grep`/`Read` for
  structural questions**: `index_repository` first if the project is not indexed,
  then `search_graph` to locate a symbol, `trace_path` for call chains,
  `get_code_snippet` for exact source, `get_architecture` for the overall
  structure, `search_code` for literals, `query_graph` for multi-hop Cypher
  queries, `detect_changes` for the impact of a git diff, and `manage_adr` for
  architecture decision records.

### Versioned configuration

The `.claude/` directory is deliberately **not** gitignored: agents, Docker setup,
permissions and tasks must stay readable in commits and on GitHub. Only secrets and
runtime state are excluded (`settings.local.json`, credentials, `projects/`,
`todos/`, `statsig/`, `shell-snapshots/`, `history.jsonl`, `codebase-memory/`,
`ide/`, `plugins/`, `safe-setup/.env`). Never commit a credential; never move
working configuration into `settings.local.json`.

## Python Best Practices

Always use:

- **omegaconf** for secrets management and YAML configuration files
- **click** for ergonomic CLI options
- **pandas** for data handling
- **telethon** when interacting with Telegram
- **botasaurus** to build a robust scraper

Always lint and format with `ruff` (`ruff check --fix`, then `ruff format`). It
is the only linter installed in the image and replaces flake8, black and isort.

Favour classes and functions over inline code, and reuse the existing ones
rather than writing new ones.

## Task Management

Tasks are organized in `.claude/tasks/`:
- `todo/` - Pending tasks
- `done/` - Completed tasks
- `analyzed/` - Tasks needing clarification
- `hold-on/` - Paused tasks
- `abandoned/` - Dropped tasks

Processing a task means moving its file to the matching column automatically.

**IMPORTANT**: One commit per task. Use `git commit --amend` if needed.

## Agents

Custom agents are defined in `.claude/commands/`. Their `description:`
frontmatter is the canonical wording; keep the lists in the READMEs in sync
with it.

- `/sceptic` - Proposes tests to find bugs
- `/rigorous` - Ensures consistency in vocabulary, structure and documentation
- `/einstein` - Tracks unnecessary complexity
- `/paranoid` - Tracks security issues in code
- `/grammarian` - Checks code and documentation quality
