# inventory_postgresql_db (MongoDB)

Despite the container name, this database container runs **MongoDB** (per `startup.sh`).

## Stable connection details for backend

The backend should connect using the following environment variables (these are the DB env vars exported by this container runtime):

- `MONGODB_URL` = `mongodb://appuser:dbuser123@localhost:5000/?authSource=admin`
- `MONGODB_DB` = `myapp`

A shell connection helper is also written to:

- `db_connection.txt` (contains a `mongosh ...` command)

## Collections and indexes

On startup, `init_seed.sh` ensures these collections exist and creates indexes:

- `roles`
  - unique index: `name`
- `users`
  - unique index: `email`
  - indexes: `roleIds`, `isActive`
- `assets`
  - unique (sparse) indexes: `assetTag`, `serialNumber`, `barcode`
  - indexes: `status`, `assignedToUserId`
- `transfers`
  - indexes: `assetId+createdAt`, `fromUserId+createdAt`, `toUserId+createdAt`, `status+createdAt`
- `audit_logs`
  - indexes: `createdAt`, `actorUserId+createdAt`, `entityType+entityId+createdAt`, `action+createdAt`

## Seed data (bootstrap admin)

`init_seed.sh` also ensures:

- role `admin` exists (permissions `["*"]`)
- role `user` exists
- at least one admin user exists

Default seed admin user:

- Email: `admin@example.com`
- Password: `ChangeMe123!`
- Display name: `System Admin`

You can override seed values via environment variables when running `init_seed.sh`:

- `SEED_ADMIN_EMAIL`
- `SEED_ADMIN_PASSWORD`
- `SEED_ADMIN_DISPLAY_NAME`

## Notes

- Password hashing/enforcement should be handled in the backend (this container seeds a minimal bootstrap user).
- The scripts are written to be idempotent and safe to re-run.
