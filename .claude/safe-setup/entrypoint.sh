#!/bin/bash

# Start Docker daemon (Docker-in-Docker)
sudo bash -c 'dockerd --host=unix:///var/run/docker.sock &>/var/log/dockerd.log &'
# Wait for the daemon to be ready
for i in $(seq 1 30); do
    if sudo docker info &>/dev/null; then
        break
    fi
    sleep 1
done
# Ensure the socket is accessible by the docker group
sudo chmod 666 /var/run/docker.sock 2>/dev/null || true

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

# Initialize rtk auto-rewrite hook (once, on first run)
if command -v rtk &>/dev/null && [ ! -f /home/osint/.claude/.rtk-initialized ]; then
    rtk init --global --auto-patch
    touch /home/osint/.claude/.rtk-initialized
fi

# Execute the command passed to the container
exec "$@"
