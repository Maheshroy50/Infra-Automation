#!/usr/bin/env bash
set -Eeuo pipefail

APP_NAME="${APP_NAME:-flask-react-app}"
APP_DIR="${APP_DIR:-/var/www/flask-react-app}"
BRANCH="${BRANCH:-main}"
FRONTEND_DEST="${FRONTEND_DEST:-/var/www/html}"
FRONTEND_BUILD_DIR="${FRONTEND_BUILD_DIR:-$APP_DIR/dist/public}"
ASSETS_BUILD_DIR="${ASSETS_BUILD_DIR:-$APP_DIR/dist/assets}"
BACKEND_DIR="${BACKEND_DIR:-$APP_DIR/src/apps/backend}"
VENV_DIR="${VENV_DIR:-$BACKEND_DIR/venv}"
SOCKET_FILE="${SOCKET_FILE:-/tmp/app.sock}"
SYSTEMD_SERVICE="${SYSTEMD_SERVICE:-$APP_NAME}"
PID_FILE="${PID_FILE:-$APP_DIR/.gunicorn.pid}"
LOG_FILE="${LOG_FILE:-$APP_DIR/deploy.log}"
GUNICORN_WORKERS="${GUNICORN_WORKERS:-2}"

timestamp() {
  date "+%Y-%m-%d %H:%M:%S"
}

log() {
  printf '[%s] %s\n' "$(timestamp)" "$*"
}

run() {
  log "$*"
  "$@"
}

handle_error() {
  local line_number="$1"
  log "Deployment failed at line ${line_number}"
  exit 1
}

require_cmd() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    log "Missing required command: ${command_name}"
    exit 1
  fi
}

as_root() {
  if command -v sudo >/dev/null 2>&1; then
    sudo "$@"
    return
  fi

  "$@"
}

sync_dir() {
  local source_dir="$1"
  local target_dir="$2"

  as_root mkdir -p "$target_dir"

  if command -v rsync >/dev/null 2>&1; then
    run as_root rsync -a --delete "${source_dir}/" "${target_dir}/"
    return
  fi

  run as_root cp -a "${source_dir}/." "$target_dir/"
}

start_gunicorn_fallback() {
  if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    run kill "$(cat "$PID_FILE")"
    rm -f "$PID_FILE"
  fi

  rm -f "$SOCKET_FILE"

  log "Starting Gunicorn without systemd"
  APP_ENV=production \
    PYTHONPATH="$BACKEND_DIR" \
    nohup "${VENV_DIR}/bin/gunicorn" \
    --workers "$GUNICORN_WORKERS" \
    --umask 007 \
    --bind "unix:${SOCKET_FILE}" \
    --chdir "$BACKEND_DIR" \
    server:app >"${APP_DIR}/gunicorn.log" 2>&1 &

  echo $! >"$PID_FILE"
  sleep 2

  if ! kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    log "Gunicorn did not stay running"
    exit 1
  fi
}

restart_backend() {
  if command -v systemctl >/dev/null 2>&1 \
    && systemctl list-unit-files "${SYSTEMD_SERVICE}.service" --no-legend 2>/dev/null \
      | grep -q "^${SYSTEMD_SERVICE}.service"; then
    run as_root systemctl daemon-reload
    run as_root systemctl restart "${SYSTEMD_SERVICE}.service"
    run as_root systemctl is-active --quiet "${SYSTEMD_SERVICE}.service"
    return
  fi

  start_gunicorn_fallback
}

reload_web_server() {
  if command -v nginx >/dev/null 2>&1; then
    run as_root nginx -t
  fi

  if command -v systemctl >/dev/null 2>&1 \
    && systemctl list-unit-files nginx.service --no-legend 2>/dev/null | grep -q "^nginx.service"; then
    run as_root systemctl reload nginx
    return
  fi

  run as_root nginx -s reload
}

trap 'handle_error "$LINENO"' ERR

mkdir -p "$(dirname "$LOG_FILE")"
exec > >(tee -a "$LOG_FILE") 2>&1

log "Starting deployment for ${APP_NAME}"
require_cmd git
require_cmd npm
require_cmd python3
require_cmd tee

# Avoid local development git hooks on the server and keep Node memory bounded on small VPSs.
export HUSKY=0
export NODE_OPTIONS="${NODE_OPTIONS:---max-old-space-size=512}"

if [[ ! -d "$APP_DIR/.git" ]]; then
  log "Application directory is not a git repository: ${APP_DIR}"
  exit 1
fi

cd "$APP_DIR"
run git fetch --prune origin
run git checkout "$BRANCH"
run git pull --ff-only origin "$BRANCH"

log "Installing Node dependencies and building frontend bundle"
run npm ci --no-audit --no-fund
run npm run build

if [[ ! -d "$FRONTEND_BUILD_DIR" ]]; then
  log "Expected frontend build directory not found: ${FRONTEND_BUILD_DIR}"
  exit 1
fi

sync_dir "$FRONTEND_BUILD_DIR" "$FRONTEND_DEST"

if [[ -d "$ASSETS_BUILD_DIR" ]]; then
  sync_dir "$ASSETS_BUILD_DIR" "${FRONTEND_DEST}/assets"
fi

log "Preparing Python virtual environment"
cd "$BACKEND_DIR"

if [[ ! -d "$VENV_DIR" ]]; then
  run python3 -m venv "$VENV_DIR"
  # Keep pip current on first bootstrap to avoid install failures on older images.
  # shellcheck disable=SC1091
  source "${VENV_DIR}/bin/activate"
  run python -m pip install --upgrade pip
else
  # shellcheck disable=SC1091
  source "${VENV_DIR}/bin/activate"
fi

run pip install -r requirements.txt

log "Restarting backend service"
restart_backend

log "Reloading Nginx"
reload_web_server

log "Deployment completed successfully"
