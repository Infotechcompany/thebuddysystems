# The Buddy Systems deployment scaffold

This repository contains a fail-fast Docker Compose scaffold for a web application and a private MariaDB backend. It is a deployment template: **the application image is not included**. Set `APP_IMAGE` to a reviewed, immutable image tag or digest before starting the stack.

## What the stack enforces

- The application and database share a private internal backend network; the database is not published to the host.
- Web ports bind to `127.0.0.1` by default for use behind an Nginx or other reverse proxy.
- Database passwords are generated into local files under `.secrets/` and mounted through Compose secrets.
- MariaDB configuration is mounted through a Compose config rather than a misdeclared volume.
- Startup waits for the database health check.
- Container logs rotate, resource limits are explicit, and `no-new-privileges` is enabled.
- The application filesystem is read-only except for its named data volume and `/tmp` tmpfs.

## Prerequisites

- Docker Engine
- Docker Compose v2 plugin (`docker compose version`)
- Bash
- OpenSSL or Python 3 for secret generation

## Configure

```bash
cp .env.example .env
```

Edit `.env` and replace both placeholders:

```text
APP_IMAGE=example.invalid/thebuddysystems/app:replace-me
MARIADB_IMAGE=example.invalid/mariadb:review-required
```

with the images you actually intend to operate. For a fresh deployment, select a maintained MariaDB LTS patch. For an existing database, retain the compatible server line until a backup, restore test, and staged migration have been completed. Prefer immutable image digests in production.

Review the application image's expected database environment variables, writable paths, health behavior, and exposed ports before deployment. The supplied application contract is:

```text
DB_HOST=db
DB_PORT=3306
DB_NAME=<from .env>
DB_USER=<from .env>
DB_PASSWORD_FILE=/run/secrets/db_password
```

Adapt the environment names and application data mount if your image uses a different contract.

## Validate without starting containers

```bash
bash setup.sh --validate-only
```

This creates missing local secret files, renders the complete Compose model, and refuses either placeholder image.

## Deploy

```bash
bash setup.sh
```

The script validates the model before changing containers, verifies that Docker Engine is reachable, then runs:

```bash
docker compose up -d --wait
```

## Verify

```bash
docker compose ps
docker compose logs --tail=100 db
docker compose config --quiet
```

Confirm that the database reports healthy, the app is running, and only the intended loopback ports are published.

## Rollback and recovery

Stop and remove containers and networks while retaining named volumes:

```bash
docker compose down
```

Restore the prior application image by resetting `APP_IMAGE` in `.env`, then rerun `bash setup.sh`. Do not delete `db_data` or `app_data` during ordinary rollback. Back up and test restoration of the database volume before schema migrations or major MariaDB upgrades.

## Secret handling

`.env` and `.secrets/` are ignored by Git. Never commit live passwords, API keys, private certificates, or database dumps. Rotating a database secret requires coordinated database credential rotation; replacing the local secret file alone does not update an existing database user. If the database volume exists and either credential file is missing, `setup.sh` fails rather than generating an incompatible replacement password.

## Production boundary

This scaffold is not a complete production platform. Before internet exposure, add a maintained reverse proxy, certificate automation, authenticated backups, monitoring, vulnerability scanning, tested restore procedures, and host-level patching. Pin image digests after review and maintain a documented upgrade/rollback window.
