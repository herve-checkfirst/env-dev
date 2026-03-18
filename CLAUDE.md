# Claude Development Guide

This document provides instructions for AI assistants (like Claude) working on this project.

## Project Overview

(To be defined by user)

## Design Principles

- Keep code simple and readable
- Document important decisions
- Test before committing

## Development Environment

A sandboxed Docker environment is available in `.claude/safe-setup/`:
- Python 3.12 with Pandas, requests, BeautifulSoup
- User `osint` with sudo access
- Persistent Claude history

See `.claude/safe-setup/HACKING.md` for setup instructions.

## Python best practises

Always use : 

- Omegaconf, fo secrets managements, and yaml configuration files
- Click, to have smart CLI options
- Pandas for data management
- Telethon if you need to interact with Telegram
- Botasaurus to build a robust scraper.

Always lint the code with black/pep8 or ruff (better)

Use as much as possible classes and functions.
Reuse functions and classes.

## Task Management

Tasks can be organized in `.claude/tasks/`:
- `todo/` - Pending tasks
- `done/` - Completed tasks
- `analyzed/` - Tasks needing clarification
- `hold-on/` - Paused tasks
- `abandoned/` - Dropped tasks
  
Processing a task implies to move the task to the right column automatically.

**IMPORTANT**: One commit per task. Use `git commit --amend` if needed.

## Agents

Custom agents are defined in `.claude/commands/`:
- `/sceptic` - Quality assessment, find bugs
- `/rigorous` - Consistency checks
- `/einstein` - Complexity tracking
- `/paranoid` - Security review
