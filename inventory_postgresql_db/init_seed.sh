#!/bin/bash
set -euo pipefail

# MongoDB initialization + seed script.
# Creates required collections & indexes and ensures at least one admin user exists.
#
# This script is designed to be safe to run multiple times (idempotent).
#
# Stable backend connection details:
# - MONGODB_URL: mongodb://<user>:<pass>@localhost:<port>/?authSource=admin
# - MONGODB_DB: myapp (default in this container)

DB_NAME="${DB_NAME:-myapp}"
DB_USER="${DB_USER:-appuser}"
DB_PASSWORD="${DB_PASSWORD:-dbuser123}"
DB_PORT="${DB_PORT:-5000}"

# Admin seed user (for initial login/bootstrap).
# NOTE: Password is stored as plain text here because hashing strategy belongs in the backend.
# Backend should hash on create/change and/or enforce migration later.
SEED_ADMIN_EMAIL="${SEED_ADMIN_EMAIL:-admin@example.com}"
SEED_ADMIN_PASSWORD="${SEED_ADMIN_PASSWORD:-ChangeMe123!}"
SEED_ADMIN_DISPLAY_NAME="${SEED_ADMIN_DISPLAY_NAME:-System Admin}"

echo "Running MongoDB init/seed..."
echo " - DB: ${DB_NAME}"
echo " - Port: ${DB_PORT}"
echo " - Seed admin email: ${SEED_ADMIN_EMAIL}"

CONN_STR="mongodb://${DB_USER}:${DB_PASSWORD}@localhost:${DB_PORT}/${DB_NAME}?authSource=admin"

mongosh "${CONN_STR}" --quiet --eval "
(function () {
  const dbName = '${DB_NAME}';
  const now = new Date();

  // ---- Collections ----
  const collections = [
    'roles',
    'users',
    'assets',
    'transfers',
    'audit_logs'
  ];

  const existing = db.getSiblingDB(dbName).getCollectionNames();
  collections.forEach((c) => {
    if (!existing.includes(c)) {
      db.getSiblingDB(dbName).createCollection(c);
    }
  });

  // ---- Indexes ----
  // Roles
  db.getSiblingDB(dbName).roles.createIndex({ name: 1 }, { unique: true, name: 'roles__name__uniq' });

  // Users
  db.getSiblingDB(dbName).users.createIndex({ email: 1 }, { unique: true, name: 'users__email__uniq' });
  db.getSiblingDB(dbName).users.createIndex({ roleIds: 1 }, { name: 'users__roleIds' });
  db.getSiblingDB(dbName).users.createIndex({ isActive: 1 }, { name: 'users__isActive' });

  // Assets
  db.getSiblingDB(dbName).assets.createIndex({ assetTag: 1 }, { unique: true, sparse: true, name: 'assets__assetTag__uniq' });
  db.getSiblingDB(dbName).assets.createIndex({ serialNumber: 1 }, { unique: true, sparse: true, name: 'assets__serialNumber__uniq' });
  db.getSiblingDB(dbName).assets.createIndex({ barcode: 1 }, { unique: true, sparse: true, name: 'assets__barcode__uniq' });
  db.getSiblingDB(dbName).assets.createIndex({ status: 1 }, { name: 'assets__status' });
  db.getSiblingDB(dbName).assets.createIndex({ assignedToUserId: 1 }, { name: 'assets__assignedToUserId' });

  // Transfers
  db.getSiblingDB(dbName).transfers.createIndex({ assetId: 1, createdAt: -1 }, { name: 'transfers__assetId__createdAt' });
  db.getSiblingDB(dbName).transfers.createIndex({ fromUserId: 1, createdAt: -1 }, { name: 'transfers__fromUserId__createdAt' });
  db.getSiblingDB(dbName).transfers.createIndex({ toUserId: 1, createdAt: -1 }, { name: 'transfers__toUserId__createdAt' });
  db.getSiblingDB(dbName).transfers.createIndex({ status: 1, createdAt: -1 }, { name: 'transfers__status__createdAt' });

  // Audit logs
  db.getSiblingDB(dbName).audit_logs.createIndex({ createdAt: -1 }, { name: 'audit_logs__createdAt' });
  db.getSiblingDB(dbName).audit_logs.createIndex({ actorUserId: 1, createdAt: -1 }, { name: 'audit_logs__actorUserId__createdAt' });
  db.getSiblingDB(dbName).audit_logs.createIndex({ entityType: 1, entityId: 1, createdAt: -1 }, { name: 'audit_logs__entity__createdAt' });
  db.getSiblingDB(dbName).audit_logs.createIndex({ action: 1, createdAt: -1 }, { name: 'audit_logs__action__createdAt' });

  // ---- Seed roles ----
  const rolesCol = db.getSiblingDB(dbName).roles;
  const usersCol = db.getSiblingDB(dbName).users;

  function ensureRole(name, permissions) {
    const existingRole = rolesCol.findOne({ name });
    if (existingRole) return existingRole;
    const doc = {
      name,
      permissions: permissions || [],
      createdAt: now,
      updatedAt: now
    };
    rolesCol.insertOne(doc);
    return rolesCol.findOne({ name });
  }

  const adminRole = ensureRole('admin', ['*']);
  ensureRole('user', []);

  // ---- Seed admin user ----
  const email = '${SEED_ADMIN_EMAIL}'.toLowerCase();
  let adminUser = usersCol.findOne({ email });

  if (!adminUser) {
    // Intentionally minimal user document; backend can extend as needed.
    usersCol.insertOne({
      email,
      password: '${SEED_ADMIN_PASSWORD}', // backend should hash in real implementation
      displayName: '${SEED_ADMIN_DISPLAY_NAME}',
      roleIds: [adminRole._id],
      isActive: true,
      createdAt: now,
      updatedAt: now
    });
    adminUser = usersCol.findOne({ email });
  } else {
    // Ensure admin role attached
    usersCol.updateOne(
      { _id: adminUser._id },
      {
        \$set: { updatedAt: now },
        \$addToSet: { roleIds: adminRole._id }
      }
    );
  }

  print('Init/seed completed.');
  print('Seed admin: ' + email);
})();
"
echo "MongoDB init/seed complete."
