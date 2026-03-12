#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_TEMPLATE_FILE="${SCRIPT_DIR}/.env.template"
ENV_FILE="${SCRIPT_DIR}/.env"
SERVICE_NAME="postgres"

usage() {
  cat <<'EOF'
Usage:
  ./database.sh generate-env
  ./database.sh create-db -d <db_name> [-u <user_name>]
  ./database.sh create-db <db_name> [-u <user_name>]

Commands:
  generate-env           Generate .env from .env.template and auto-generate POSTGRES_PASSWORD
  create-db              Create a new database after checks

Options for create-db:
  -d <db_name>           Database name (required)
  -u <user_name>         Owner username (optional)
  -h                     Show help
EOF
}

error() {
  echo "ERROR: $*" >&2
}

generate_password() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 36 | tr -dc 'A-Za-z0-9' | head -c 24
  else
    tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24
  fi
}

is_valid_identifier() {
  [[ "$1" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]
}

require_docker_compose() {
  if ! command -v docker >/dev/null 2>&1; then
    error "docker command not found."
    exit 1
  fi
  if ! docker compose version >/dev/null 2>&1; then
    error "docker compose is not available."
    exit 1
  fi
}

load_env() {
  if [ ! -f "${ENV_FILE}" ]; then
    error ".env not found: ${ENV_FILE}. Run './database.sh generate-env' first."
    exit 1
  fi

  set -a
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +a

  : "${POSTGRES_USER:?POSTGRES_USER is required in .env}"
  : "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required in .env}"
}

run_psql() {
  local sql="$1"
  docker compose exec -T "${SERVICE_NAME}" env PGPASSWORD="${POSTGRES_PASSWORD}" \
    psql -v ON_ERROR_STOP=1 -U "${POSTGRES_USER}" -d postgres -tAc "${sql}"
}

check_container_running() {
  local cid=""
  cid="$(docker compose ps -q "${SERVICE_NAME}" 2>/dev/null || true)"
  if [ -z "${cid}" ]; then
    return 1
  fi

  [ "$(docker inspect -f '{{.State.Running}}' "${cid}" 2>/dev/null || true)" = "true" ]
}

generate_env() {
  if [ ! -f "${ENV_TEMPLATE_FILE}" ]; then
    error ".env.template not found: ${ENV_TEMPLATE_FILE}"
    exit 1
  fi

  if [ -f "${ENV_FILE}" ]; then
    error ".env already exists: ${ENV_FILE}"
    echo "Tip: backup or remove .env and retry."
    exit 1
  fi

  local random_password=""
  random_password="$(generate_password)"

  cp "${ENV_TEMPLATE_FILE}" "${ENV_FILE}"
  if grep -q '^POSTGRES_PASSWORD=' "${ENV_FILE}"; then
    sed -i "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=${random_password}/" "${ENV_FILE}"
  else
    printf '\nPOSTGRES_PASSWORD=%s\n' "${random_password}" >>"${ENV_FILE}"
  fi

  chmod 600 "${ENV_FILE}" || true
  echo ".env generated successfully: ${ENV_FILE}"
}

create_database() {
  local db_name=""
  local db_owner=""
  local owner_specified="false"

  OPTIND=1
  while getopts ":d:u:h" opt; do
    case "${opt}" in
      d)
        db_name="${OPTARG}"
        ;;
      u)
        db_owner="${OPTARG}"
        owner_specified="true"
        ;;
      h)
        usage
        exit 0
        ;;
      :)
        error "Option -${OPTARG} requires an argument."
        exit 1
        ;;
      \?)
        error "Unknown option: -${OPTARG}"
        usage
        exit 1
        ;;
    esac
  done
  shift $((OPTIND - 1))

  if [ -z "${db_name}" ] && [ $# -ge 1 ]; then
    db_name="$1"
    shift
  fi
  if [ $# -gt 0 ]; then
    error "Unexpected arguments: $*"
    usage
    exit 1
  fi

  if [ -z "${db_name}" ]; then
    error "Database name is required. Use -d <db_name>."
    usage
    exit 1
  fi
  if ! is_valid_identifier "${db_name}"; then
    error "Invalid database name '${db_name}'. Use letters/numbers/underscore and start with a letter or underscore."
    exit 1
  fi

  load_env

  if [ -z "${db_owner}" ]; then
    db_owner="${POSTGRES_USER}"
  fi
  if ! is_valid_identifier "${db_owner}"; then
    error "Invalid username '${db_owner}'. Use letters/numbers/underscore and start with a letter or underscore."
    exit 1
  fi

  require_docker_compose

  if ! check_container_running; then
    error "PostgreSQL container is not running."
    echo "Tip: run 'docker compose up -d' in ${SCRIPT_DIR}"
    exit 1
  fi

  if ! run_psql "SELECT 1;" >/dev/null 2>&1; then
    error "PostgreSQL is not ready yet."
    exit 1
  fi

  local db_exists=""
  db_exists="$(run_psql "SELECT 1 FROM pg_database WHERE datname='${db_name}';" | tr -d '[:space:]')"
  if [ "${db_exists}" = "1" ]; then
    error "Database '${db_name}' already exists."
    exit 1
  fi

  local owner_exists=""
  owner_exists="$(run_psql "SELECT 1 FROM pg_roles WHERE rolname='${db_owner}';" | tr -d '[:space:]')"

  local user_password=""
  if [ "${owner_specified}" = "true" ]; then
    user_password="$(generate_password)"
    if [ "${owner_exists}" = "1" ]; then
      run_psql "ALTER ROLE \"${db_owner}\" WITH LOGIN PASSWORD '${user_password}';" >/dev/null
      echo "Role '${db_owner}' exists. Password updated."
    else
      run_psql "CREATE USER \"${db_owner}\" WITH PASSWORD '${user_password}';" >/dev/null
      echo "Role '${db_owner}' created."
    fi
  else
    if [ "${owner_exists}" != "1" ]; then
      error "Owner '${db_owner}' does not exist. Check POSTGRES_USER in .env or use -u <user_name>."
      exit 1
    fi
  fi

  run_psql "CREATE DATABASE \"${db_name}\" OWNER \"${db_owner}\";" >/dev/null
  echo "Database '${db_name}' created successfully. Owner: ${db_owner}"

  if [ "${owner_specified}" = "true" ]; then
    echo "Credentials:"
    echo "  username: ${db_owner}"
    echo "  password: ${user_password}"
  fi
}

main() {
  cd "${SCRIPT_DIR}"

  local cmd="${1:-}"
  case "${cmd}" in
    generate-env)
      generate_env
      ;;
    create-db)
      shift
      create_database "$@"
      ;;
    -h|--help|help|"")
      usage
      ;;
    *)
      error "Unknown command: ${cmd}"
      usage
      exit 1
      ;;
  esac
}

main "$@"
