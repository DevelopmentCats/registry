#!/usr/bin/env bash

set -euo pipefail

PORT=${PORT}
LOG_PATH=${LOG_PATH}
SERVER_BASE_PATH=${SERVER_BASE_PATH}
CONFIG=${CONFIG}

BOLD='\033[0;1m'

printf "$${BOLD}Installing pgAdmin!\n"

if ! command -v pip > /dev/null 2>&1; then
    echo "pip is not installed"
    echo "Please install pip in your Dockerfile/VM image before using this module"
    exit 1
fi

if ! command -v pgadmin4 > /dev/null 2>&1; then
  pip install pgadmin4-web
  echo "pgAdmin has been installed\n\n"
else
  echo "pgAdmin is already installed\n\n"
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