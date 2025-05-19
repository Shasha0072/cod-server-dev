#!/bin/bash

# This script launches a code-server instance for a specified user
# Usage: launch-code-server username [port]

USERNAME=$1
PORT=${2:-8443}  # Default port is 8443 if not specified

# Ensure required directories exist
mkdir -p /home/$USERNAME/.config/code-server/User
mkdir -p /home/$USERNAME/.local/share/code-server
mkdir -p /mnt/syncstore/$USERNAME

# Set correct ownership
chown -R $USERNAME:$USERNAME /home/$USERNAME/.config/code-server
chown -R $USERNAME:$USERNAME /home/$USERNAME/.local/share/code-server
chown -R $USERNAME:$USERNAME /mnt/syncstore/$USERNAME

# Get user's UID and GID
USER_UID=$(id -u $USERNAME)
USER_GID=$(id -g $USERNAME)

# Stop any existing container for this user
docker stop code-server-$USERNAME 2>/dev/null
docker rm code-server-$USERNAME 2>/dev/null

# Start the container
docker run -d \
  --name code-server-$USERNAME \
  -p $PORT:8443 \
  -v "/home/$USERNAME/.config/code-server:/home/coder/.config" \
  -v "/home/$USERNAME/.local/share/code-server:/home/coder/.local/share/code-server" \
  -v "/mnt/syncstore/$USERNAME:/home/coder/workspace" \
  -v "/opt/code-server/certificates:/certificates:ro" \
  -u "$USER_UID:$USER_GID" \
  -e "PASSWORD=password" \
  --restart=always \
  code-server-custom-extension \
  --cert=/certificates/cert.pem \
  --cert-key=/certificates/key.pem \
  --bind-addr=0.0.0.0:8443 \
  --auth=password \
  /home/coder/workspace

echo "Started code-server for user $USERNAME on port $PORT"
echo "URL: https://$(hostname -I | awk '{print $1}'):$PORT"
echo "Password: password (change this via the config file or environment variable)"