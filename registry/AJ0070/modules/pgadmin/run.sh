#!/usr/bin/env bash

set -euo pipefail

PORT=${PORT}
LOG_PATH=${LOG_PATH}
SERVER_BASE_PATH=${SERVER_BASE_PATH}

BOLD='\033[0;1m'

printf "$${BOLD}Installing pgAdmin!\n"

# Check if Python 3 is available
if ! command -v python3 >/dev/null 2>&1; then
  echo "⚠️  Warning: Python 3 is not installed. Please install Python 3 before using this module."
  exit 0
fi

# Setup pgAdmin directories (from Terraform configuration)
PGADMIN_DATA_DIR="${PGADMIN_DATA_DIR}"
PGADMIN_LOG_DIR="${PGADMIN_LOG_DIR}"
PGADMIN_VENV_DIR="${PGADMIN_VENV_DIR}"

printf "Setting up pgAdmin directories...\n"
mkdir -p "$PGADMIN_DATA_DIR"
mkdir -p "$PGADMIN_LOG_DIR"

# Check if pgAdmin virtual environment already exists and is working
if [ -f "$PGADMIN_VENV_DIR/bin/pgadmin4" ] && [ -f "$PGADMIN_VENV_DIR/bin/activate" ]; then
  printf "🥳 pgAdmin virtual environment already exists\n\n"
else
  printf "Creating Python virtual environment for pgAdmin...\n"
  if ! python3 -m venv "$PGADMIN_VENV_DIR"; then
    echo "⚠️  Warning: Failed to create virtual environment"
    exit 0
  fi
  
  printf "Installing pgAdmin 4 in virtual environment...\n"
  if ! "$PGADMIN_VENV_DIR/bin/pip" install pgadmin4; then
    echo "⚠️  Warning: Failed to install pgAdmin4"
    exit 0
  fi
  
  printf "🥳 pgAdmin has been installed successfully\n\n"
fi

printf "$${BOLD}Configuring pgAdmin...\n"

if [ -f "$PGADMIN_VENV_DIR/bin/pgadmin4" ]; then
  # Create pgAdmin config file using Terraform-generated configuration
  cat > "$PGADMIN_DATA_DIR/config_local.py" << EOF
# pgAdmin configuration for Coder workspace
${CONFIG}
EOF

  printf "📄 Config written to $PGADMIN_DATA_DIR/config_local.py\n"
  
  printf "$${BOLD}Starting pgAdmin in background...\n"
  printf "📝 Check logs at $${LOG_PATH}\n"
  printf "🌐 Serving at http://localhost:${PORT}${SERVER_BASE_PATH}\n"
  
  cd "$PGADMIN_DATA_DIR"
  "$PGADMIN_VENV_DIR/bin/pgadmin4" > "$${LOG_PATH}" 2>&1 &
else
  printf "⚠️  Warning: pgAdmin4 virtual environment not found\n"
  printf "📝 Installation may have failed - check logs above\n"
fi