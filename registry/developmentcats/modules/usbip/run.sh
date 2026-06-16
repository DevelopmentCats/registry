#!/usr/bin/env bash

LOG_PATH="${LOG_PATH}"
MODE="${MODE}"
REMOTE_HOST="${REMOTE_HOST}"
REMOTE_PORT="${REMOTE_PORT}"
BUS_IDS="${BUS_IDS}"
SERVER_PORT="${SERVER_PORT}"
BIND_BUS_IDS="${BIND_BUS_IDS}"
INSTALL_PACKAGES="${INSTALL_PACKAGES}"

set -o pipefail

mkdir -p "$(dirname "$LOG_PATH")" 2> /dev/null || true
exec > >(tee -a "$LOG_PATH") 2>&1

log() { printf '[usbip] %s\n' "$*"; }
warn() { printf '[usbip][warn] %s\n' "$*" >&2; }

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo > /dev/null 2>&1; then
    SUDO="sudo"
  else
    warn "not running as root and sudo is unavailable; privileged operations will be skipped"
  fi
fi

run_priv() {
  if [ -n "$SUDO" ] || [ "$(id -u)" -eq 0 ]; then
    $SUDO "$@"
  else
    warn "skipping privileged command: $*"
    return 1
  fi
}

detect_pm() {
  if command -v apt-get > /dev/null 2>&1; then
    echo apt
    return
  fi
  if command -v dnf > /dev/null 2>&1; then
    echo dnf
    return
  fi
  if command -v yum > /dev/null 2>&1; then
    echo yum
    return
  fi
  if command -v zypper > /dev/null 2>&1; then
    echo zypper
    return
  fi
  if command -v pacman > /dev/null 2>&1; then
    echo pacman
    return
  fi
  if command -v apk > /dev/null 2>&1; then
    echo apk
    return
  fi
  echo unknown
}

install_usbip() {
  if command -v usbip > /dev/null 2>&1; then
    log "usbip already installed: $(usbip version 2> /dev/null | head -n1)"
    return 0
  fi

  local pm
  pm="$(detect_pm)"
  log "installing usbip tools via $pm"

  case "$pm" in
    apt)
      run_priv env DEBIAN_FRONTEND=noninteractive apt-get update -y \
        || warn "apt-get update failed"
      local kver pkg
      kver="$(uname -r)"
      pkg="linux-tools-$kver"
      if ! run_priv env DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" hwdata; then
        warn "could not install $pkg; falling back to linux-tools-generic"
        run_priv env DEBIAN_FRONTEND=noninteractive apt-get install -y linux-tools-generic hwdata \
          || warn "apt install fallback failed"
      fi
      ;;
    dnf)
      run_priv dnf install -y usbip hwdata || warn "dnf install failed"
      ;;
    yum)
      run_priv yum install -y usbip hwdata || warn "yum install failed"
      ;;
    zypper)
      run_priv zypper --non-interactive install usbip hwdata || warn "zypper install failed"
      ;;
    pacman)
      run_priv pacman -Sy --noconfirm usbip hwdata || warn "pacman install failed"
      ;;
    apk)
      run_priv apk add --no-cache usbip hwdata || warn "apk install failed"
      ;;
    *)
      warn "no supported package manager detected; install usbip tools manually"
      return 1
      ;;
  esac

  if ! command -v usbip > /dev/null 2>&1; then
    warn "usbip CLI still not on PATH after install; on Debian/Ubuntu it lives under /usr/lib/linux-tools/<kver>/"
  fi
}

load_module() {
  local mod="$1"
  if lsmod 2> /dev/null | awk '{print $1}' | grep -qx "$mod"; then
    log "kernel module $mod already loaded"
    return 0
  fi
  if run_priv modprobe "$mod" 2> /dev/null; then
    log "loaded kernel module $mod"
    return 0
  fi
  warn "could not load kernel module $mod; the workspace likely lacks privileged access or the host kernel does not ship USB/IP. Continuing."
  return 1
}

attach_devices() {
  if [ -z "$REMOTE_HOST" ]; then
    log "no remote_host configured; skipping auto-attach"
    return 0
  fi
  if ! command -v usbip > /dev/null 2>&1; then
    warn "usbip CLI not available; cannot attach $REMOTE_HOST"
    return 1
  fi
  if [ -z "$BUS_IDS" ]; then
    log "remote_host is set but bus_ids is empty; listing available devices from $REMOTE_HOST:$REMOTE_PORT"
    usbip list -r "$REMOTE_HOST" 2>&1 || warn "usbip list failed against $REMOTE_HOST:$REMOTE_PORT"
    return 0
  fi
  for bus in $BUS_IDS; do
    log "attaching $bus from $REMOTE_HOST:$REMOTE_PORT"
    if ! run_priv usbip attach -r "$REMOTE_HOST" -b "$bus" --tcp-port "$REMOTE_PORT"; then
      warn "failed to attach $bus from $REMOTE_HOST"
    fi
  done
}

start_server() {
  if ! command -v usbipd > /dev/null 2>&1; then
    warn "usbipd not available; skipping server startup"
    return 1
  fi
  if pgrep -x usbipd > /dev/null 2>&1; then
    log "usbipd already running"
  else
    log "starting usbipd on port $SERVER_PORT"
    if ! run_priv sh -c "usbipd --tcp-port $SERVER_PORT >>'$LOG_PATH' 2>&1 &"; then
      warn "failed to start usbipd"
      return 1
    fi
    sleep 1
  fi
  for bus in $BIND_BUS_IDS; do
    log "binding local bus $bus"
    if ! run_priv usbip bind -b "$bus"; then
      warn "failed to bind $bus"
    fi
  done
}

main() {
  log "mode=$MODE install_packages=$INSTALL_PACKAGES"

  if [ "$INSTALL_PACKAGES" = "true" ]; then
    install_usbip || warn "package install reported issues; continuing"
  fi

  case "$MODE" in
    client)
      load_module vhci-hcd || true
      attach_devices || true
      ;;
    server)
      load_module usbip-host || true
      start_server || true
      ;;
    both)
      load_module vhci-hcd || true
      load_module usbip-host || true
      start_server || true
      attach_devices || true
      ;;
    *)
      warn "unknown mode '$MODE'; expected client|server|both"
      exit 0
      ;;
  esac

  log "done"
}

main "$@"
