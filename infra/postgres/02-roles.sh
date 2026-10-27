#!/bin/sh
# Creates the restricted database users. Migrations run as $POSTGRES_USER, which owns
# every table; the api and workers connect as these users instead.
#
#   app user      reads and writes security, core and payments. The security and
#                 payments migrations revoke UPDATE and DELETE on audit_log and
#                 ledger_entries, so those stay append only.
#   workers user  reads and writes its own schema, and reads and marks the outbox
#                 tables (granted by the core and payments migrations).
set -eu

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  -v app_user="$APP_DB_USER" -v app_password="$APP_DB_PASSWORD" \
  -v workers_user="$WORKERS_DB_USER" -v workers_password="$WORKERS_DB_PASSWORD" \
  -v owner="$POSTGRES_USER" <<'SQL'
CREATE ROLE :"app_user" LOGIN PASSWORD :'app_password';
CREATE ROLE :"workers_user" LOGIN PASSWORD :'workers_password';

GRANT USAGE ON SCHEMA security, core, payments TO :"app_user";
ALTER DEFAULT PRIVILEGES FOR ROLE :"owner" IN SCHEMA security, core, payments
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO :"app_user";
ALTER DEFAULT PRIVILEGES FOR ROLE :"owner" IN SCHEMA security, core, payments
  GRANT USAGE, SELECT ON SEQUENCES TO :"app_user";

GRANT USAGE ON SCHEMA core, payments, workers TO :"workers_user";
ALTER DEFAULT PRIVILEGES FOR ROLE :"owner" IN SCHEMA workers
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO :"workers_user";
ALTER DEFAULT PRIVILEGES FOR ROLE :"owner" IN SCHEMA workers
  GRANT USAGE, SELECT ON SEQUENCES TO :"workers_user";
SQL
