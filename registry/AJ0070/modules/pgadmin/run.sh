#!/usr/bin/env bash

set -euo pipefail

PORT=${PORT}
LOG_PATH=${LOG_PATH}
SERVER_BASE_PATH=${SERVER_BASE_PATH}

BOLD='\033[0;1m'

printf "$${BOLD}Installing pgAdmin!\n"

INSTALLER=""
check_available_installer() {
  echo "Checking for available package managers..."
  
  # Check for system package managers first (much faster)
  if command -v apt-get >/dev/null 2>&1; then
    echo "APT package manager found"
    INSTALLER="apt"
    return
  fi
  
  if command -v dnf >/dev/null 2>&1; then
    echo "DNF package manager found"
    INSTALLER="dnf"
    return
  fi
  
  if command -v yum >/dev/null 2>&1; then
    echo "YUM package manager found"
    INSTALLER="yum"
    return
  fi
  
  if command -v brew >/dev/null 2>&1; then
    echo "Homebrew found (macOS)"
    INSTALLER="brew"
    return
  fi
  
  # Fall back to Python pip installation (as recommended by pgAdmin docs)
  echo "No system package manager found, checking for pip..."
  
  if command -v pip >/dev/null 2>&1; then
    echo "pip is available - will use recommended pgAdmin installation method"
    INSTALLER="pip"
    return
  fi
  
  echo "No valid installer found"
  echo "Please install a system package manager (apt-get, dnf, yum, brew) or pip"
  return 1
}

if ! command -v pgadmin4 >/dev/null 2>&1; then
  if ! check_available_installer; then
    printf "⚠️  Warning: No package manager available for pgAdmin installation\n"
  else
    printf "Installing pgAdmin with $${INSTALLER}...\n"
    case $INSTALLER in
    apt)
      printf "Installing pgAdmin via APT (fast system package)...\n"
      # Add pgAdmin APT repository
      if command -v sudo >/dev/null 2>&1; then
        curl -fsS https://www.pgadmin.org/static/packages_pgadmin_org.pub | sudo gpg --dearmor -o /usr/share/keyrings/packages-pgadmin-org.gpg 2>/dev/null || echo "Warning: Failed to add pgAdmin GPG key"
        sudo sh -c 'echo "deb [signed-by=/usr/share/keyrings/packages-pgadmin-org.gpg] https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/$(lsb_release -cs) pgadmin4 main" > /etc/apt/sources.list.d/pgadmin4.list' 2>/dev/null || echo "Warning: Failed to add pgAdmin repository"
        sudo apt-get update -qq 2>/dev/null || echo "Warning: Failed to update package lists"
        sudo apt-get install -y -qq pgadmin4-web && printf "🥳 pgAdmin has been installed via APT\n\n" || echo "Warning: Failed to install pgAdmin via APT"
      else
        echo "Warning: sudo access required for APT installation"
      fi
      ;;
    dnf)
      printf "Installing pgAdmin via DNF (fast system package)...\n"
      if command -v sudo >/dev/null 2>&1; then
        sudo rpm --import https://www.pgadmin.org/static/packages_pgadmin_org.pub 2>/dev/null || echo "Warning: Failed to import pgAdmin GPG key"
        sudo dnf install -y -q https://ftp.postgresql.org/pub/pgadmin/pgadmin4/yum/pgadmin4-redhat-repo-2-1.noarch.rpm 2>/dev/null || echo "Warning: Failed to add pgAdmin repository"
        sudo dnf install -y -q pgadmin4-web && printf "🥳 pgAdmin has been installed via DNF\n\n" || echo "Warning: Failed to install pgAdmin via DNF"
      else
        echo "Warning: sudo access required for DNF installation"
      fi
      ;;
    yum)
      printf "Installing pgAdmin via YUM (fast system package)...\n"
      if command -v sudo >/dev/null 2>&1; then
        sudo rpm --import https://www.pgadmin.org/static/packages_pgadmin_org.pub 2>/dev/null || echo "Warning: Failed to import pgAdmin GPG key"
        sudo yum install -y -q https://ftp.postgresql.org/pub/pgadmin/pgadmin4/yum/pgadmin4-redhat-repo-2-1.noarch.rpm 2>/dev/null || echo "Warning: Failed to add pgAdmin repository"
        sudo yum install -y -q pgadmin4-web && printf "🥳 pgAdmin has been installed via YUM\n\n" || echo "Warning: Failed to install pgAdmin via YUM"
      else
        echo "Warning: sudo access required for YUM installation"
      fi
      ;;
    brew)
      printf "Installing pgAdmin via Homebrew...\n"
      brew install --cask pgadmin4 && printf "🥳 pgAdmin has been installed via Homebrew\n\n" || echo "Warning: Failed to install pgAdmin via Homebrew"
      ;;
         pip)
       printf "Installing pgadmin4 via pip (following official pgAdmin documentation)...\n"
       if command -v timeout >/dev/null 2>&1; then
         timeout 600 pip install --user pgadmin4 --verbose && printf "🥳 pgAdmin has been installed via pip\n\n" || echo "Warning: Failed to install pgAdmin with pip (timeout or installation error)"
       else
         pip install --user pgadmin4 --verbose && printf "🥳 pgAdmin has been installed via pip\n\n" || echo "Warning: Failed to install pgAdmin with pip"
       fi
       ;;
     esac
  fi
else
  printf "🥳 pgAdmin is already installed\n\n"
fi

printf "$${BOLD}Configuring pgAdmin...\n"

if command -v pgadmin4 >/dev/null 2>&1; then
  mkdir -p ~/.pgadmin

  cat > ~/.pgadmin/config_local.py << EOF
# pgAdmin configuration
${CONFIG}
EOF

  printf "📄 Config written to ~/.pgadmin/config_local.py\n"
else
  printf "⚠️  Warning: Skipping configuration - pgAdmin4 not found\n"
fi

if command -v pgadmin4 >/dev/null 2>&1; then
  printf "$${BOLD}Starting pgAdmin in background...\n"
  printf "📝 Check logs at $${LOG_PATH}\n"
  printf "🌐 Serving at http://localhost:${PORT}${SERVER_BASE_PATH}\n"
  pgadmin4 > $${LOG_PATH} 2>&1 &
else
  printf "⚠️  Warning: pgAdmin4 is not available - installation may have failed\n"
  printf "📝 Check installation logs above for details\n"
  printf "🔧 You may need to install pgAdmin4 manually or check your Python environment\n"
fi