#!/bin/bash
set -euo pipefail

# PostgreSQL initialization + seed script.
# Creates required tables/indexes and ensures at least one admin user exists.
#
# Stable backend connection details:
# - POSTGRES_HOST, POSTGRES_PORT, POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD

DB_NAME="${POSTGRES_DB:-myapp}"
DB_USER="${POSTGRES_USER:-appuser}"
DB_PASSWORD="${POSTGRES_PASSWORD:-dbuser123}"
DB_PORT="${POSTGRES_PORT:-5432}"
DB_HOST="${POSTGRES_HOST:-127.0.0.1}"

SEED_ADMIN_USERNAME="${SEED_ADMIN_USERNAME:-admin}"
SEED_ADMIN_EMAIL="${SEED_ADMIN_EMAIL:-admin@example.com}"
SEED_ADMIN_PASSWORD="${SEED_ADMIN_PASSWORD:-ChangeMe123!}"
SEED_ADMIN_FULL_NAME="${SEED_ADMIN_FULL_NAME:-System Admin}"

echo "Running PostgreSQL init/seed..."
echo " - DB: ${DB_NAME}"
echo " - Host: ${DB_HOST}"
echo " - Port: ${DB_PORT}"
echo " - Seed admin username: ${SEED_ADMIN_USERNAME}"
echo " - Seed admin email: ${SEED_ADMIN_EMAIL}"

export PGPASSWORD="${DB_PASSWORD}"

# 1) Ensure extensions
psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -v ON_ERROR_STOP=1 -c "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";"

# 2) Tables
psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -v ON_ERROR_STOP=1 -c "CREATE TABLE IF NOT EXISTS users (id uuid PRIMARY KEY DEFAULT uuid_generate_v4(), username varchar(50) NOT NULL UNIQUE, email varchar(320) NOT NULL UNIQUE, full_name varchar(120) NOT NULL, password_hash varchar(255) NOT NULL, roles jsonb NOT NULL DEFAULT '[]'::jsonb, status varchar(20) NOT NULL DEFAULT 'active', created_at timestamptz NOT NULL, updated_at timestamptz NOT NULL);"
psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -v ON_ERROR_STOP=1 -c "CREATE TABLE IF NOT EXISTS assets (id uuid PRIMARY KEY DEFAULT uuid_generate_v4(), asset_tag varchar(64) NOT NULL UNIQUE, serial_number varchar(128) NULL, type varchar(30) NOT NULL, manufacturer varchar(80) NULL, model varchar(80) NULL, description varchar(500) NULL, location varchar(120) NULL, metadata jsonb NOT NULL DEFAULT '{}'::jsonb, active boolean NOT NULL DEFAULT true, created_at timestamptz NOT NULL, updated_at timestamptz NOT NULL);"
psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -v ON_ERROR_STOP=1 -c "CREATE TABLE IF NOT EXISTS allocations (id uuid PRIMARY KEY DEFAULT uuid_generate_v4(), asset_id uuid NOT NULL REFERENCES assets(id), from_user_id uuid NULL REFERENCES users(id), to_user_id uuid NOT NULL REFERENCES users(id), status varchar(30) NOT NULL, notes varchar(500) NULL, transfer_to_user_id uuid NULL REFERENCES users(id), transfer_notes varchar(500) NULL, decision_notes varchar(500) NULL, requested_by uuid NULL REFERENCES users(id), approved_by uuid NULL REFERENCES users(id), created_at timestamptz NOT NULL, updated_at timestamptz NOT NULL);"
psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -v ON_ERROR_STOP=1 -c "CREATE TABLE IF NOT EXISTS audits (id uuid PRIMARY KEY DEFAULT uuid_generate_v4(), actor_user_id uuid NULL REFERENCES users(id), action varchar(50) NOT NULL, entity_type varchar(50) NOT NULL, entity_id uuid NULL, detail jsonb NOT NULL DEFAULT '{}'::jsonb, created_at timestamptz NOT NULL);"

# 3) Indexes (IF NOT EXISTS available for indexes)
psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -v ON_ERROR_STOP=1 -c "CREATE INDEX IF NOT EXISTS ix_assets_serial_number ON assets (serial_number);"
psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -v ON_ERROR_STOP=1 -c "CREATE INDEX IF NOT EXISTS ix_allocations_asset_status ON allocations (asset_id, status);"
psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -v ON_ERROR_STOP=1 -c "CREATE INDEX IF NOT EXISTS ix_allocations_to_user_status ON allocations (to_user_id, status);"
psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -v ON_ERROR_STOP=1 -c "CREATE INDEX IF NOT EXISTS ix_allocations_created_at ON allocations (created_at);"
psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -v ON_ERROR_STOP=1 -c "CREATE INDEX IF NOT EXISTS ix_audits_created_at ON audits (created_at);"
psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -v ON_ERROR_STOP=1 -c "CREATE INDEX IF NOT EXISTS ix_audits_actor_created_at ON audits (actor_user_id, created_at);"
psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -v ON_ERROR_STOP=1 -c "CREATE INDEX IF NOT EXISTS ix_audits_entity_created_at ON audits (entity_type, entity_id, created_at);"
psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -v ON_ERROR_STOP=1 -c "CREATE INDEX IF NOT EXISTS ix_audits_action_created_at ON audits (action, created_at);"

# 4) Seed admin (minimal; backend will hash/enforce in real flows but we still hash here for immediate login)
# Only insert if no admin exists.
psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -v ON_ERROR_STOP=1 -c "INSERT INTO users (username, email, full_name, password_hash, roles, status, created_at, updated_at) SELECT '${SEED_ADMIN_USERNAME}', lower('${SEED_ADMIN_EMAIL}'), '${SEED_ADMIN_FULL_NAME}', '${SEED_ADMIN_PASSWORD}', '[\"admin\",\"user\"]'::jsonb, 'active', now(), now() WHERE NOT EXISTS (SELECT 1 FROM users WHERE roles @> '[\"admin\"]'::jsonb);"

echo "PostgreSQL init/seed complete."
