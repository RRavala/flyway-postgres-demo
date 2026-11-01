#!/usr/bin/env bash
# Run Flyway (via Docker) against the RDS instance that the pilot-infra repo creates.
# Run it from a machine whose IP is allowed on the instance's security group
# (the allowed_cidr you gave pilot-infra), or the connection will time out.
#
# Usage: scripts/migrate-rds.sh [info|migrate|validate]   (default: info)
#
# Connection details come from the environment:
#   FLYWAY_URL       jdbc:postgresql://<endpoint>:5432/test?sslmode=require
#   FLYWAY_USER      master username (default in pilot-infra: rravala)
#   FLYWAY_PASSWORD  master password (Secrets Manager, "rds!db-..." secret)
set -euo pipefail

cmd="${1:-info}"
root="$(cd "$(dirname "$0")/.." && pwd)"

: "${FLYWAY_URL:?Set FLYWAY_URL, e.g. jdbc:postgresql://<endpoint>:5432/test?sslmode=require}"
: "${FLYWAY_USER:?Set FLYWAY_USER}"
: "${FLYWAY_PASSWORD:?Set FLYWAY_PASSWORD}"

# MSYS_NO_PATHCONV stops Git Bash on Windows from mangling the container paths.
MSYS_NO_PATHCONV=1 docker run --rm \
  -v "$root/sql:/flyway/sql" \
  -v "$root/flyway.conf:/flyway/conf/flyway.conf" \
  -e FLYWAY_URL -e FLYWAY_USER -e FLYWAY_PASSWORD \
  "${FLYWAY_IMAGE:-redgate/flyway:latest}" -connectRetries=3 "$cmd"
