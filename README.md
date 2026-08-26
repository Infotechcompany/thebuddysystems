# The Buddy Systems deployment scaffold

A small Docker Compose scaffold for running one web application with a private MariaDB service. The repository emphasizes repeatable validation, local secret files, network separation, bounded logs, and rollback without deleting persistent volumes.

> **Status:** infrastructure scaffold, not a complete production application. Replace `your-app-image:1.0.0`, review the database version, and complete application-specific backup, restore, TLS, observability, and recovery testing before exposure.

## Architecture

```text
host loopback ports 8080 / 8443
              |
              v
         app service
       /             \
frontend bridge   internal backend bridge
                         |
                         v
                    MariaDB :3306
                    (no host port)
```

The application joins both networks. The database joins only the internal backend network, so it is reachable by service name `db` from the application but is not published on the host.

## Prerequisites

- Docker Engine with the Compose v2 plugin (`docker compose`)
- Bash
- An application image that understands `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, and `DB_PASSWORD_FILE`
- A tested backup and restore procedure for the selected application and database image

## Configure and start

```bash
git clone https://github.com/Infotechcompany/thebuddysystems.git
cd thebuddysystems
cp .env.example .env
$EDITOR .env
./setup.sh
```

`setup.sh` performs these steps:

1. Verifies Docker and Compose v2.
2. Creates `.env` from the non-secret example when needed.
3. Creates `.secrets/` with mode `0700`.
4. Prompts for the MariaDB root and application passwords without terminal echo.
5. Writes each secret atomically with mode `0600`.
6. Runs `docker compose config --quiet` before changing runtime state.
7. Starts the stack with orphan cleanup and prints service status.

Validate configuration without starting containers:

```bash
./setup.sh --validate-only
```

## Configuration

Non-secret settings live in `.env`, which is intentionally ignored by Git:

| Variable | Purpose | Safe default |
|---|---|---|
| `APP_IMAGE` | Application image tag or digest | Placeholder; must be replaced |
| `APP_HTTP_BIND` | Host address for HTTP | `127.0.0.1` |
| `APP_HTTP_PORT` | Host HTTP port | `8080` |
| `APP_HTTPS_BIND` | Host address for HTTPS | `127.0.0.1` |
| `APP_HTTPS_PORT` | Host HTTPS port | `8443` |
| `DB_IMAGE` | MariaDB image | Existing `mariadb:10.5` baseline |
| `DB_NAME` | Application database | `thebuddysystems` |
| `DB_USER` | Application database user | `thebuddysystems` |

Binding to `0.0.0.0` exposes a port on every host interface. Do that only behind an intentionally configured firewall or reverse proxy.

Compose continues to derive its project name from the checkout-directory basename, matching the legacy deployment behavior and preserving the associated named-volume identity. Do not add or change `COMPOSE_PROJECT_NAME` on an existing deployment unless you are intentionally migrating its volumes and have verified backup, restore, and rollback. Record `docker compose ls` and `docker volume ls` before any such migration.

An earlier unmerged revision of this repair could generate `.env` with `COMPOSE_PROJECT_NAME=thebuddysystems`. In a checkout whose directory has another name, setup detects that exact stale value and stops before secret migration or Compose startup because it cannot know which named-volume set contains the installation. Inspect `docker compose ls` and `docker volume ls`. Remove the line to retain the legacy checkout-derived identity. If the fixed `thebuddysystems` identity is intentional and its volumes have been verified, acknowledge it for that invocation with `THEBUDDYSYSTEMS_ALLOW_PROJECT_NAME=thebuddysystems ./setup.sh`; this acknowledgement does not migrate or copy volumes.

Secrets are local files and are never committed:

```text
.secrets/db_root_password.txt
.secrets/db_password.txt
```

Compose mounts them read-only under `/run/secrets`. File-backed Compose secrets reduce accidental environment leakage but do **not** encrypt the files on the Docker host; host access controls, disk encryption, backup policy, and secret rotation remain required.

When upgrading an installation created by the legacy setup, `setup.sh` atomically migrates `.secrets/db_root_pwd.txt` and `.secrets/mysql_pwd.txt` (or the same files under the former `secrets/` path) to the current names before prompting. If the canonical destination and any retained legacy copy differ—or multiple legacy copies differ—setup fails closed instead of guessing which credential matches the persistent database. Legacy source files are retained for rollback; verify the application and database with the migrated credentials before securely archiving or removing those copies.

## Security properties

- The database has no published host port.
- The backend network is marked `internal`.
- The application must wait for database health before startup.
- Both services use `no-new-privileges`.
- The application root filesystem is read-only except for its named data volume and bounded temporary filesystems.
- JSON logs are size- and count-limited.
- Local environment files, secret files, logs, and backups are ignored by Git.
- CI resolves the Compose model and asserts the network, secret, privilege, persistence, and dependency invariants.

These controls are defense in depth, not a substitute for image provenance, vulnerability management, TLS termination, host hardening, or application security review.

## Verification

```bash
docker compose config --quiet
docker compose ps
docker compose logs --tail=100 db
docker compose logs --tail=100 app
```

Expected state:

- `db` eventually reports healthy.
- `app` starts only after database health succeeds.
- `docker compose port db 3306` returns no published host mapping.
- The application can resolve `db` on the backend network.

CI additionally checks shell syntax, the Portainer template JSON, and the fully resolved Compose topology.

## Backup, change, and rollback discipline

Before an application or database image upgrade:

1. Create and verify an application-consistent database backup.
2. Record the current image digests and resolved configuration.
3. Test restore into a separate project name and volumes.
4. Change one dependency boundary at a time.
5. Verify health, logs, application transactions, and restoration again.

A configuration rollback that preserves data is normally:

```bash
docker compose down --remove-orphans
git checkout <known-good-commit>
docker compose config --quiet
docker compose up -d
```

`docker compose down` preserves named volumes. **Do not add `--volumes` or `-v` unless permanent data deletion is explicitly intended and independently verified.**

Changing `.secrets/db_password.txt` does not automatically alter an already initialized MariaDB account. Rotate the database credential through an authorized SQL procedure, update the secret file atomically, and then recreate the dependent application container. Test this procedure before relying on it during an incident.

## Repository layout

```text
.
├── .env.example
├── .github/workflows/compose-ci.yml
├── .secrets/                 # local only; created by setup.sh
├── config/my.cnf
├── docker-compose.yml
├── setup.sh
└── templates-2.0.json
```

## Known limitations

- The application image is intentionally unspecified.
- The retained MariaDB 10.5 image requires a separately planned lifecycle upgrade; changing the database major version inside this repair would combine unrelated migration risk.
- No automated database backup, restore drill, external monitoring, reverse proxy, or certificate lifecycle is supplied.
- Compose resource behavior varies by engine/platform; validate limits on the actual deployment host.
- Production acceptance requires image provenance, vulnerability scanning, load testing, recovery testing, and owner-approved operational procedures.

See [SECURITY.md](SECURITY.md) for vulnerability reporting guidance.
