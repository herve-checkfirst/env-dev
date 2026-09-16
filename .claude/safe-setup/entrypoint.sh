#!/bin/bash

# Start Docker daemon (Docker-in-Docker)
sudo bash -c 'dockerd --host=unix:///var/run/docker.sock &>/var/log/dockerd.log &'
# Wait for the daemon to be ready, and say so if it never comes up: otherwise
# the failure only surfaces later as an opaque "Cannot connect to the Docker
# daemon" from whatever command happens to need it first.
dockerd_ready=no
for i in $(seq 1 30); do
    if sudo docker info &>/dev/null; then
        dockerd_ready=yes
        break
    fi
    sleep 1
done
if [ "$dockerd_ready" = no ]; then
    echo "WARNING: the Docker daemon did not start within 30s." >&2
    echo "         Docker-in-Docker is unavailable; see /var/log/dockerd.log." >&2
fi
# Restrict the socket to the docker group, which osint belongs to (see
# Dockerfile). A world-writable socket would hand root to any process here.
sudo chown root:docker /var/run/docker.sock 2>/dev/null || true
sudo chmod 660 /var/run/docker.sock 2>/dev/null || true

# Configure git user/email from environment variables if provided
if [ -n "$GIT_USER_NAME" ]; then
    git config --global user.name "$GIT_USER_NAME"
fi

if [ -n "$GIT_USER_EMAIL" ]; then
    git config --global user.email "$GIT_USER_EMAIL"
fi

# Set up persistent bash history
# We use a directory volume and store the file inside it
HISTFILE=/home/osint/.bash_history_dir/.bash_history
export HISTFILE

# Create the history file if it doesn't exist
touch "$HISTFILE"

# Add to bashrc for interactive shells
if ! grep -q "HISTFILE=/home/osint/.bash_history_dir" /home/osint/.bashrc 2>/dev/null; then
    echo 'export HISTFILE=/home/osint/.bash_history_dir/.bash_history' >> /home/osint/.bashrc
    echo 'export HISTSIZE=10000' >> /home/osint/.bashrc
    echo 'export HISTFILESIZE=20000' >> /home/osint/.bashrc
fi

# Install the rtk hook if it is not actually in place.
#
# The check probes the real state via `rtk init --show` rather than trusting a
# marker file: ~/.claude lives in a Docker volume that outlives image rebuilds,
# so a marker can easily claim a hook that is no longer there.
#
# --auto-patch answers the settings.json prompt. --trust-filters answers the
# custom-filter prompt, which means detected filters are accepted WITHOUT
# review; filters transform the command output Claude sees, so this trades a
# safety check for an unattended start. See HACKING.md.
#
# rtk is absent on arm64 (upstream ships no static linux/arm64 build), which is
# why this is not treated as an error.
if command -v rtk &>/dev/null; then
    if rtk init --show 2>/dev/null | grep -q 'PreToolUse'; then
        : # hook already installed
    elif rtk init --global --auto-patch --trust-filters; then
        echo "rtk hook installed: Bash output is now compressed."
    else
        echo "WARNING: rtk init failed, CLI output compression is disabled." >&2
        echo "         Run 'rtk init --global --auto-patch --trust-filters' manually." >&2
    fi
else
    echo "NOTE: rtk is not installed in this image; no output compression."
fi

# CBM_CACHE_DIR is set as an ENV in the Dockerfile so that it also reaches
# `docker compose exec` shells, which never run this entrypoint. Only the
# directory itself needs creating here: the volume is mounted empty on first use.
mkdir -p "${CBM_CACHE_DIR:-/home/osint/.claude/codebase-memory}"

# Execute the command passed to the container
exec "$@"
