# inventory_postgresql_db (PostgreSQL)

This database container runs **PostgreSQL** (despite having previously been MongoDB).

## Stable connection details for backend

The backend should connect using the following environment variables (exported by this container runtime):

- `POSTGRES_HOST` = `localhost`
- `POSTGRES_PORT` = `5432`
- `POSTGRES_DB` = `myapp`
- `POSTGRES_USER` = `appuser`
- `POSTGRES_PASSWORD` = `dbuser123`

A shell connection helper is written to:

- `db_connection.txt` (contains a `psql postgresql://...` command)

## Schema

On startup, this container ensures tables exist (idempotent):

- `users`
- `assets`
- `allocations`
- `audits`

## Seed data (bootstrap admin)

On startup, the container ensures at least one admin user exists.

Default seed admin user:

- Username: `admin`
- Email: `admin@example.com`
- Password: `ChangeMe123!`
- Full name: `System Admin`

You can override seed values via environment variables:

- `SEED_ADMIN_USERNAME`
- `SEED_ADMIN_EMAIL`
- `SEED_ADMIN_PASSWORD`
- `SEED_ADMIN_FULL_NAME`

## Notes

- Password hashing should be handled in the backend. The container seeds a minimal bootstrap user.
- Scripts are designed to be idempotent and safe to re-run.
