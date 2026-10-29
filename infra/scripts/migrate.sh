#!/bin/sh
# Runs every package's Alembic migrations, in dependency order, inside the api
# container. Each package keeps its own version table in its own schema, so the
# histories never collide. Usage: migrate.sh [upgrade head | downgrade base]
set -eu
action="${1:-upgrade}"
target="${2:-head}"
for pkg in security payments backend; do
  if [ -f "/src/$pkg/alembic.ini" ]; then
    echo "== $pkg: alembic $action $target"
    (cd "/src/$pkg" && alembic "$action" "$target")
  fi
done
