#!/usr/bin/env bash
# First deployment / manual update for a server with Podman only.
# Run from any directory: ./deploy.sh (or /path/to/unirent/deploy.sh)
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$ROOT_DIR/infra/env/.env"
COMPOSE_FILE="$ROOT_DIR/infra/compose.yaml"
DOMAIN="unirent.siddharths.me"

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf '\n==> %s\n' "$*"; }

command -v podman >/dev/null 2>&1 || fail "Podman is required. Install Podman and a Compose provider first."
podman compose version >/dev/null 2>&1 || fail "'podman compose' has no working Compose provider. Install podman-compose or Docker Compose as a Podman provider."
command -v curl >/dev/null 2>&1 || fail "curl is required for the final health check."

if [[ ! -f "$ENV_FILE" ]]; then
  cp "$ROOT_DIR/infra/env/staging.env.example" "$ENV_FILE"
  chmod 600 "$ENV_FILE"
  cat >&2 <<EOF
Created $ENV_FILE from the staging template.
Edit it and fill in all required secrets, then run this script again.
At minimum configure DB passwords, SERVICE_TOKEN, JWT_SECRET, Microsoft/Firebase
credentials, Razorpay credentials and ADMIN_EMAIL/ADMIN_PASSWORD.
EOF
  exit 2
fi

# These deployment-specific values are fixed for this server and can safely
# be populated when the user started from the general development env file.
set_env_value() {
  local key="$1" value="$2"
  if grep -q "^${key}=" "$ENV_FILE"; then
    sed -i "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
  else
    printf '%s=%s\n' "$key" "$value" >> "$ENV_FILE"
  fi
}
set_env_value PROFILE staging
set_env_value ENVIRONMENT staging
set_env_value STAGING_DOMAIN "$DOMAIN"
set_env_value STORAGE_PUBLIC_URL "https://$DOMAIN"
set_env_value API_BIND 127.0.0.1
set_env_value HOST_BIND 127.0.0.1

required_vars=(
  POSTGRES_PASSWORD APP_DB_PASSWORD WORKERS_DB_PASSWORD
  MINIO_ROOT_PASSWORD SERVICE_TOKEN JWT_SECRET
  MS_CLIENT_ID MS_TENANT_ID MS_ALLOWED_DOMAIN FIREBASE_PROJECT_ID
  ADMIN_EMAIL ADMIN_PASSWORD RAZORPAY_KEY_ID RAZORPAY_KEY_SECRET
  RAZORPAY_WEBHOOK_SECRET GRAFANA_ADMIN_PASSWORD
)
for var_name in "${required_vars[@]}"; do
  if ! awk -F= -v key="$var_name" '$1 == key && length(substr($0, index($0, "=") + 1)) > 0 { found=1 } END { exit !found }' "$ENV_FILE"; then
    fail "$var_name is empty or missing in $ENV_FILE. Fill the staging secrets before deployment."
  fi
done

env_value() {
  awk -F= -v key="$1" '$1 == key { value=substr($0, index($0, "=") + 1) } END { print value }' "$ENV_FILE"
}

configured_domain="$(env_value STAGING_DOMAIN)"
if [[ "$configured_domain" != "$DOMAIN" ]]; then
  fail "Set STAGING_DOMAIN=$DOMAIN in $ENV_FILE (currently '${configured_domain:-unset}')."
fi
if [[ "$(env_value STORAGE_PUBLIC_URL)" != "https://$DOMAIN" ]]; then
  fail "Set STORAGE_PUBLIC_URL=https://$DOMAIN in $ENV_FILE so signed photo URLs use the public HTTPS host."
fi
if [[ "$(env_value PUSH_MODE)" == "fcm" && ! -f "$ROOT_DIR/infra/env/fcm.json" ]]; then
  fail "PUSH_MODE=fcm requires the Firebase service-account file at $ROOT_DIR/infra/env/fcm.json. Add it or set PUSH_MODE=log."
fi

compose() {
  podman compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" --profile staging "$@"
}

# Compose files and volume paths are relative to infra/, so run from the repo.
cd "$ROOT_DIR"

info "Building the API and worker images locally with Podman"
compose build api workers

info "Starting the database, cache, broker, object store and API"
compose up -d postgres redis kafka minio api

info "Creating the photo bucket if it does not exist"
compose --profile init run --rm minio-init

info "Running database migrations"
compose exec -T api sh /src/infra/scripts/migrate.sh

info "Starting workers and the HTTPS front door"
compose up -d workers caddy

info "Waiting up to 180 seconds for the HTTPS API at https://$DOMAIN/readyz"
deadline=$((SECONDS + 180))
until curl --silent --show-error --fail --max-time 8 "https://$DOMAIN/readyz" >/dev/null 2>&1; do
  if (( SECONDS >= deadline )); then
    compose ps
    fail "The HTTPS readiness check timed out. Check DNS, inbound ports 80/443, Caddy logs (podman compose ... logs caddy), and API logs."
  fi
  sleep 5
done

printf '\nUniRent is running at https://%s\n' "$DOMAIN"
printf 'API readiness: https://%s/readyz\n' "$DOMAIN"
printf 'To inspect services: podman compose -f %q --env-file %q --profile staging ps\n' "$COMPOSE_FILE" "$ENV_FILE"
