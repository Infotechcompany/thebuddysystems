#!/bin/bash

# Define network name
DOCKER_NETWORK="scoobydoo"

# Define secrets directory and files
SECRETS_DIR="./.secrets"
DB_ROOT_PWD_FILE="${SECRETS_DIR}/db_root_pwd.txt"
MYSQL_PWD_FILE="${SECRETS_DIR}/mysql_pwd.txt"

# Check if Docker network exists, if not create it
if ! docker network ls | grep -q "$DOCKER_NETWORK"; then
  echo "Creating Docker network: $DOCKER_NETWORK"
  docker network create "$DOCKER_NETWORK"
else
  echo "Docker network $DOCKER_NETWORK already exists"
fi

# Setup secrets directory and files
echo "Setting up secrets..."
mkdir -p "$SECRETS_DIR"

# Prompt for secrets if files don't exist
if [ ! -f "$DB_ROOT_PWD_FILE" ]; then
  read -sp 'Enter the MariaDB Root Password: ' DB_ROOT_PWD
  echo "$DB_ROOT_PWD" > "$DB_ROOT_PWD_FILE"
fi

if [ ! -f "$MYSQL_PWD_FILE" ]; then
  read -sp 'Enter the MySQL Password: ' MYSQL_PWD
  echo "$MYSQL_PWD" > "$MYSQL_PWD_FILE"
fi

# Set file permissions for secrets
chmod 600 "$DB_ROOT_PWD_FILE" "$MYSQL_PWD_FILE"

# Start Docker containers
echo "Starting Docker containers..."
docker-compose up -d

echo "Setup completed."
