#!/usr/bin/env bash
# Run Flyway (via Docker) against the RDS instance created by infra/.
# Usage: scripts/migrate-rds.sh [info|migrate|validate]   (default: migrate)
set -euo pipefail

cmd="${1:-migrate}"
root="$(cd "$(dirname "$0")/.." && pwd)"

url="$(terraform -chdir="$root/infra" output -raw jdbc_url)"
user="$(terraform -chdir="$root/infra" output -raw username)"
secret_arn="$(terraform -chdir="$root/infra" output -raw password_secret_arn)"
region="$(terraform -chdir="$root/infra" output -raw region)"
password="$(aws secretsmanager get-secret-value --region "$region" \
  --secret-id "$secret_arn" --query SecretString --output text \
  | python -c 'import sys,json; print(json.load(sys.stdin)["password"])')"

# MSYS_NO_PATHCONV stops Git Bash on Windows from mangling the container paths.
MSYS_NO_PATHCONV=1 docker run --rm \
  -v "$root/sql:/flyway/sql" \
  -v "$root/flyway.conf:/flyway/conf/flyway.conf" \
  -e FLYWAY_URL="$url" -e FLYWAY_USER="$user" -e FLYWAY_PASSWORD="$password" \
  redgate/flyway "$cmd"
