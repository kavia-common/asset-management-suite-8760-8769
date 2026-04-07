#!/bin/bash
set -euo pipefail

DB_NAME="${POSTGRES_DB:-myapp}"
DB_USER="${POSTGRES_USER:-appuser}"
DB_PASSWORD="${POSTGRES_PASSWORD:-dbuser123}"
DB_PORT="${POSTGRES_PORT:-5432}"
DB_HOST="${POSTGRES_HOST:-127.0.0.1}"

echo "Starting PostgreSQL setup..."
echo " - DB: ${DB_NAME}"
echo " - User: ${DB_USER}"
echo " - Host: ${DB_HOST}"
echo " - Port: ${DB_PORT}"

# Ensure postgres is running (best-effort; environment may already have it).
if ! sudo -u postgres pg_isready -h "${DB_HOST}" -p "${DB_PORT}" >/dev/null 2>&1; then
  echo "PostgreSQL not ready; attempting to start service..."
  # Try common start commands; ignore failures if service mgmt is not available.
  (sudo service postgresql start >/dev/null 2>&1) || true
  (sudo systemctl start postgresql >/dev/null 2>&1) || true
fi

# Wait for readiness
for i in {1..20}; do
  if sudo -u postgres pg_isready -h "${DB_HOST}" -p "${DB_PORT}" >/dev/null 2>&1; then
    echo "PostgreSQL is ready!"
    break
  fi
  echo "Waiting for PostgreSQL... ($i/20)"
  sleep 1
done

if ! sudo -u postgres pg_isready -h "${DB_HOST}" -p "${DB_PORT}" >/dev/null 2>&1; then
  echo "ERROR: PostgreSQL is not ready on ${DB_HOST}:${DB_PORT}"
  exit 1
fi

# Create role (user) and database if missing.
# Note: we use DO blocks so it's still a single statement per -c execution.
sudo -u postgres psql -h "${DB_HOST}" -p "${DB_PORT}" -d postgres -v ON_ERROR_STOP=1 -c "DO \$\$ BEGIN IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${DB_USER}') THEN CREATE ROLE ${DB_USER} LOGIN PASSWORD '${DB_PASSWORD}'; END IF; END \$\$;"
sudo -u postgres psql -h "${DB_HOST}" -p "${DB_PORT}" -d postgres -v ON_ERROR_STOP=1 -c "DO \$\$ BEGIN IF NOT EXISTS (SELECT FROM pg_database WHERE datname = '${DB_NAME}') THEN CREATE DATABASE ${DB_NAME} OWNER ${DB_USER}; END IF; END \$\$;"

# Ensure schema + seed (idempotent)
POSTGRES_HOST="${DB_HOST}" POSTGRES_PORT="${DB_PORT}" POSTGRES_DB="${DB_NAME}" POSTGRES_USER="${DB_USER}" POSTGRES_PASSWORD="${DB_PASSWORD}" ./init_seed.sh || true

# Save connection command
echo "psql postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}" > db_connection.txt
echo "Connection string saved to db_connection.txt"

# Save environment variables for Node.js DB viewer
cat > db_visualizer/postgres.env << EOF
export POSTGRES_HOST="${DB_HOST}"
export POSTGRES_PORT="${DB_PORT}"
export POSTGRES_DB="${DB_NAME}"
export POSTGRES_USER="${DB_USER}"
export POSTGRES_PASSWORD="${DB_PASSWORD}"
export POSTGRES_URL="postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}"
EOF

echo "PostgreSQL setup complete!"
echo ""
echo "Environment variables saved to db_visualizer/postgres.env"
echo "To use with Node.js viewer, run: source db_visualizer/postgres.env"
echo ""
echo "To connect:"
cat db_connection.txt
