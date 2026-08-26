#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

SECRETS_DIR="$ROOT_DIR/.secrets"
DB_ROOT_PASSWORD_FILE="$SECRETS_DIR/db_root_password.txt"
DB_PASSWORD_FILE="$SECRETS_DIR/db_password.txt"
LEGACY_DB_ROOT_PASSWORD_FILES=(
  "$SECRETS_DIR/db_root_pwd.txt"
  "$ROOT_DIR/secrets/db_root_pwd.txt"
)
LEGACY_DB_PASSWORD_FILES=(
  "$SECRETS_DIR/mysql_pwd.txt"
  "$ROOT_DIR/secrets/mysql_pwd.txt"
)

log() {
  printf '[thebuddysystems] %s\n' "$*"
}

fail() {
  printf '[thebuddysystems] ERROR: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

validate_project_identity() {
  local checkout_name=${ROOT_DIR##*/}

  if [[ "$checkout_name" == "thebuddysystems" ]] \
    || ! grep -Fqx 'COMPOSE_PROJECT_NAME=thebuddysystems' .env; then
    return 0
  fi
  if [[ "${THEBUDDYSYSTEMS_ALLOW_PROJECT_NAME:-}" == "thebuddysystems" ]]; then
    log "Using acknowledged Compose project name 'thebuddysystems' instead of checkout-derived '$checkout_name'"
    return 0
  fi

  fail "Stale generated COMPOSE_PROJECT_NAME=thebuddysystems detected in .env for checkout '$checkout_name'. Refusing to select a possibly different named-volume set. Inspect 'docker compose ls' and 'docker volume ls'; remove that line to preserve checkout-derived project '$checkout_name', or, only after verifying the fixed identity is intentional, rerun with THEBUDDYSYSTEMS_ALLOW_PROJECT_NAME=thebuddysystems."
}

migrate_legacy_secret() {
  local destination=$1
  shift
  local candidate source="" temporary

  if [[ -s "$destination" ]]; then
    chmod 600 "$destination"
    source=$destination
  fi

  for candidate in "$@"; do
    [[ -s "$candidate" ]] || continue
    if [[ -n "$source" ]] && ! cmp -s -- "$source" "$candidate"; then
      fail "Conflicting canonical or legacy secret files for $destination: $source and $candidate"
    fi
    [[ -n "$source" ]] || source=$candidate
  done

  [[ -n "$source" ]] || return 0
  [[ "$source" != "$destination" ]] || return 0

  temporary="$(mktemp "${destination}.XXXXXX")"
  chmod 600 "$temporary"
  cp -- "$source" "$temporary"
  mv -f -- "$temporary" "$destination"
  log "Migrated legacy secret $(basename "$source") to $(basename "$destination"); retained the source for rollback"
}

write_secret() {
  local destination=$1
  local prompt=$2
  local secret temporary

  if [[ -s "$destination" ]]; then
    chmod 600 "$destination"
    return 0
  fi

  [[ -t 0 ]] || fail "Missing $destination and no interactive terminal is available"

  read -r -s -p "$prompt" secret
  printf '\n'
  [[ -n "$secret" ]] || fail "Secret values must not be empty"
  [[ "$secret" != *$'\n'* && "$secret" != *$'\r'* ]] || fail "Secret values must be one line"

  temporary="$(mktemp "${destination}.XXXXXX")"
  chmod 600 "$temporary"
  printf '%s\n' "$secret" >"$temporary"
  mv -f "$temporary" "$destination"
  unset secret
}

require_command docker
require_command cmp
require_command grep
docker compose version >/dev/null 2>&1 || fail "Docker Compose v2 is required (docker compose)"

if [[ ! -f .env ]]; then
  [[ -f .env.example ]] || fail ".env.example is missing"
  cp .env.example .env
  chmod 600 .env
  log "Created .env from .env.example; review APP_IMAGE and deployment settings before exposure"
fi

validate_project_identity

mkdir -p -m 700 "$SECRETS_DIR"
migrate_legacy_secret "$DB_ROOT_PASSWORD_FILE" "${LEGACY_DB_ROOT_PASSWORD_FILES[@]}"
migrate_legacy_secret "$DB_PASSWORD_FILE" "${LEGACY_DB_PASSWORD_FILES[@]}"
write_secret "$DB_ROOT_PASSWORD_FILE" 'Enter the MariaDB root password: '
write_secret "$DB_PASSWORD_FILE" 'Enter the application database password: '

log "Validating the fully resolved Compose model"
docker compose config --quiet

if [[ "${1:-}" == "--validate-only" ]]; then
  log "Compose validation passed"
  exit 0
fi

[[ $# -eq 0 ]] || fail "Unknown argument: $1 (supported: --validate-only)"

log "Starting services"
docker compose up -d --remove-orphans

docker compose ps
log "Deployment submitted. Verify that db reports healthy before testing the application."
