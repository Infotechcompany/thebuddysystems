#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly ENV_FILE="${SCRIPT_DIR}/.env"
readonly ENV_EXAMPLE="${SCRIPT_DIR}/.env.example"
readonly SECRETS_DIR="${SCRIPT_DIR}/.secrets"
readonly ROOT_PASSWORD_FILE="${SECRETS_DIR}/db_root_password.txt"
readonly DB_PASSWORD_FILE="${SECRETS_DIR}/db_password.txt"

mode="up"
case "${1:-}" in
  "") ;;
  --validate-only) mode="validate" ;;
  --help|-h)
    cat <<'EOF'
Usage: ./setup.sh [--validate-only]

  --validate-only  create missing local inputs and validate Compose without starting containers
EOF
    exit 0
    ;;
  *)
    printf 'Unknown option: %s\n' "$1" >&2
    exit 64
    ;;
esac

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

read_project_name() {
  local value
  value="${COMPOSE_PROJECT_NAME:-}"
  if [[ -z "$value" ]]; then
    value="$(awk -F= '/^[[:space:]]*COMPOSE_PROJECT_NAME=/{sub(/^[^=]*=/, ""); print; exit}' "$ENV_FILE")"
  fi
  value="${value:-thebuddysystems}"
  [[ "$value" =~ ^[a-z0-9][a-z0-9_-]*$ ]] ||
    fail "COMPOSE_PROJECT_NAME must match ^[a-z0-9][a-z0-9_-]*$"
  printf '%s' "$value"
}

generate_secret() {
  local destination="$1"
  if [[ -s "$destination" ]]; then
    return
  fi

  local temporary
  temporary="$(mktemp "${SECRETS_DIR}/.secret.XXXXXX")"
  trap 'rm -f "$temporary"' RETURN

  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 32 | tr -d '\n' >"$temporary"
  elif command -v python3 >/dev/null 2>&1; then
    python3 - <<'PY' >"$temporary"
import secrets
print(secrets.token_hex(32), end="")
PY
  else
    fail "openssl or python3 is required to generate secrets"
  fi

  [[ -s "$temporary" ]] || fail "secret generation produced an empty file"
  chmod 600 "$temporary"
  mv -f "$temporary" "$destination"
  trap - RETURN
}

require_command docker
docker compose version >/dev/null 2>&1 || fail "Docker Compose v2 plugin is required"

cd "$SCRIPT_DIR"
umask 077

if [[ ! -f "$ENV_FILE" ]]; then
  cp "$ENV_EXAMPLE" "$ENV_FILE"
  printf 'Created %s from the example template.\n' "$ENV_FILE"
fi
chmod 600 "$ENV_FILE"

project_name="$(read_project_name)"
if [[ "$mode" == "up" ]]; then
  docker info >/dev/null 2>&1 || fail "Docker Engine is not reachable"
  if docker volume inspect "${project_name}_db_data" >/dev/null 2>&1; then
    if [[ ! -s "$ROOT_PASSWORD_FILE" || ! -s "$DB_PASSWORD_FILE" ]]; then
      fail "database volume ${project_name}_db_data exists but local credential files are missing; restore the original secrets or perform an approved credential-recovery procedure"
    fi
  fi
fi

mkdir -p "$SECRETS_DIR"
chmod 700 "$SECRETS_DIR"
chmod g-s "$SECRETS_DIR" 2>/dev/null || true
generate_secret "$ROOT_PASSWORD_FILE"
generate_secret "$DB_PASSWORD_FILE"

# Parse and normalize the complete model before any container is changed.
docker compose config --quiet
rendered_images="$(docker compose config --images)"
if grep -Eq 'replace-me|review-required' <<<"$rendered_images"; then
  fail "set APP_IMAGE and MARIADB_IMAGE in .env to reviewed image tags or digests"
fi

if [[ "$mode" == "validate" ]]; then
  printf 'Compose validation passed.\n'
  exit 0
fi

docker compose up -d --wait
docker compose ps

cat <<'EOF'
Deployment completed.

Rollback without deleting persistent data:
  docker compose down

Destructive removal of database and application volumes is intentionally not automated.
EOF
