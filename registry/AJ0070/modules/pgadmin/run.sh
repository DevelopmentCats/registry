#!/usr/bin/env bash

set -euo pipefail

PORT=${PORT}
LOG_PATH=${LOG_PATH}
SERVER_BASE_PATH=${SERVER_BASE_PATH}

BOLD='\033[0;1m'

printf "$${BOLD}Installing pgAdmin!\n"

INSTALLER=""
check_available_installer() {
  echo "Checking for a supported installer"
  if command -v pipx >/dev/null 2>&1; then
    echo "pipx is installed"
    INSTALLER="pipx"
    return
  fi
  if command -v uv >/dev/null 2>&1; then
    echo "uv is installed"
    INSTALLER="uv"
    return
  fi
  if command -v pip >/dev/null 2>&1; then
    echo "pip is installed - using with --user flag"
    INSTALLER="pip"
    return
  fi
  echo "No valid installer found"
  echo "Please install pipx, uv, or pip in your Dockerfile/VM image before using this module"
  exit 1
}

if ! command -v pgadmin4 >/dev/null 2>&1; then
  check_available_installer
  printf "Installing pgAdmin with $${INSTALLER}...\n"
  case $INSTALLER in
  pipx)
    pipx install pgadmin4-web &&
      printf "🥳 pgAdmin has been installed\n\n"
    ;;
  uv)
    uv pip install pgadmin4-web &&
      printf "🥳 pgAdmin has been installed\n\n"
    ;;
  pip)
    pip install --user pgadmin4-web &&
      printf "🥳 pgAdmin has been installed\n\n"
    ;;
  esac
else
  printf "🥳 pgAdmin is already installed\n\n"
fi

printf "$${BOLD}Configuring pgAdmin...\n"

# Create pgAdmin config directory
mkdir -p ~/.pgadmin

# Write config file
cat > ~/.pgadmin/config_local.py << EOF
# pgAdmin configuration
${CONFIG}
EOF

printf "📄 Config written to ~/.pgadmin/config_local.py\n"

printf "$${BOLD}Starting pgAdmin in background...\n"
printf "📝 Check logs at $${LOG_PATH}\n"
printf "🌐 Serving at http://localhost:${PORT}${SERVER_BASE_PATH}\n"

pgadmin4 > $${LOG_PATH} 2>&1 &