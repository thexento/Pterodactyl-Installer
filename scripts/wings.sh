#!/bin/bash

set -e

######################################################################################
#                                                                                    #
#  Pterodactyl Installer by XENTO — Wings Script                                    #
#  https://github.com/thexento/Pterodactyl-Installer                                 #
#  https://pterodactyl-installer.xento.xyz                                           #
#                                                                                    #
#  Copyright (C) 2024 - 2026, XENTO                                                  #
#  Licensed under the GNU General Public License v3.0                                #
#                                                                                    #
#  This script is not associated with the official Pterodactyl Project.              #
#                                                                                    #
######################################################################################

LOG_FILE="/var/log/pterodactyl-xento.log"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[ OK ]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERR ]${NC}  $*" >&2; }

# ──────────────────────────────────────────────
#  OS detection
# ──────────────────────────────────────────────
detect_os() {
  if [ -f /etc/os-release ]; then
    source /etc/os-release
    OS="$ID"
    OS_VER="$VERSION_ID"
    OS_VER_MAJOR="${VERSION_ID%%.*}"
  else
    error "Cannot detect OS."
    exit 1
  fi
  success "Detected OS: $OS $OS_VER"
}

validate_fqdn() {
  [[ "$1" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]] || \
  [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

validate_email() {
  [[ "$1" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]
}

# ──────────────────────────────────────────────
#  Collect all inputs BEFORE installing anything
# ──────────────────────────────────────────────
collect_inputs() {
  echo -e ""
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  ${BOLD}Wings Configuration${NC}"
  echo -e "  ${DIM}All questions are asked before installation begins.${NC}"
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e ""

  # FQDN for Wings node
  while true; do
    echo -n -e "  ${WHITE}Wings FQDN or IP (this server):${NC} "
    read -r FQDN
    if validate_fqdn "$FQDN"; then break
    else error "Invalid domain or IP. Try again."; fi
  done

  # Install MariaDB for database host feature?
  while true; do
    echo -n -e "  ${WHITE}Install MariaDB (for database host feature)? [y/N]:${NC} "
    read -r DB_INPUT
    case "$DB_INPUT" in
      [Yy]*) INSTALL_MARIADB=true;  break ;;
      [Nn]*|"") INSTALL_MARIADB=false; break ;;
      *) error "Enter y or n." ;;
    esac
  done

  if [ "$INSTALL_MARIADB" == true ]; then
    echo -n -e "  ${WHITE}Database host user password (for pterodactyluser):${NC} "
    read -rs DBHOST_PASSWORD
    echo ""
    while [[ ${#DBHOST_PASSWORD} -lt 8 ]]; do
      error "Password must be at least 8 characters."
      echo -n -e "  ${WHITE}Database host user password:${NC} "
      read -rs DBHOST_PASSWORD
      echo ""
    done
    CONFIGURE_DBHOST=true
  else
    CONFIGURE_DBHOST=false
    DBHOST_PASSWORD=""
  fi

  # SSL
  echo -e ""
  echo -e "  ${WHITE}SSL Options:${NC}"
  echo -e "    ${WHITE}[1]${NC} Use Let's Encrypt (requires valid domain)"
  echo -e "    ${WHITE}[2]${NC} No SSL"
  while true; do
    echo -n -e "  ${WHITE}SSL choice [1-2]:${NC} "
    read -r SSL_CHOICE
    case "$SSL_CHOICE" in
      1) CONFIGURE_LETSENCRYPT=true;  break ;;
      2) CONFIGURE_LETSENCRYPT=false; break ;;
      *) error "Enter 1 or 2." ;;
    esac
  done

  if [ "$CONFIGURE_LETSENCRYPT" == true ]; then
    while true; do
      echo -n -e "  ${WHITE}Email for Let's Encrypt:${NC} "
      read -r LE_EMAIL
      if validate_email "$LE_EMAIL"; then break
      else error "Invalid email."; fi
    done
  else
    LE_EMAIL=""
  fi

  # Firewall
  echo -e ""
  while true; do
    echo -n -e "  ${WHITE}Configure UFW firewall? [y/N]:${NC} "
    read -r FW_INPUT
    case "$FW_INPUT" in
      [Yy]*) CONFIGURE_FIREWALL=true;  break ;;
      [Nn]*|"") CONFIGURE_FIREWALL=false; break ;;
      *) error "Enter y or n." ;;
    esac
  done

  # Summary
  echo -e ""
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  ${BOLD}Installation Summary${NC}"
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  Wings FQDN  : ${WHITE}${FQDN}${NC}"
  echo -e "  MariaDB     : ${WHITE}$([ "$INSTALL_MARIADB" == true ] && echo "Yes" || echo "No")${NC}"
  echo -e "  SSL         : ${WHITE}$([ "$CONFIGURE_LETSENCRYPT" == true ] && echo "Let's Encrypt" || echo "None")${NC}"
  echo -e "  Firewall    : ${WHITE}$([ "$CONFIGURE_FIREWALL" == true ] && echo "Yes" || echo "No")${NC}"
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e ""

  while true; do
    echo -n -e "  ${WHITE}Confirm and start installation? [y/N]:${NC} "
    read -r CONFIRM
    case "$CONFIRM" in
      [Yy]*) break ;;
      [Nn]*|"") error "Installation cancelled."; exit 0 ;;
      *) error "Enter y or n." ;;
    esac
  done
  echo -e ""
}

# ──────────────────────────────────────────────
#  Package helpers
# ──────────────────────────────────────────────
update_repos() {
  export DEBIAN_FRONTEND=noninteractive
  case "$OS" in
    ubuntu|debian)
      apt-get update -y &>>"$LOG_FILE"
      ;;
    rocky|almalinux)
      dnf update -y &>>"$LOG_FILE"
      ;;
  esac
}

install_packages() {
  case "$OS" in
    ubuntu|debian)
      apt-get install -y $@ &>>"$LOG_FILE"
      ;;
    rocky|almalinux)
      dnf install -y $@ &>>"$LOG_FILE"
      ;;
  esac
}

# ──────────────────────────────────────────────
#  Firewall
# ──────────────────────────────────────────────
configure_firewall() {
  info "Configuring UFW firewall..."
  install_packages "ufw"
  ufw allow 22   &>>"$LOG_FILE"
  ufw allow 8080 &>>"$LOG_FILE"
  ufw allow 2022 &>>"$LOG_FILE"
  [ "$CONFIGURE_LETSENCRYPT" == true ] && ufw allow 80 &>>"$LOG_FILE" && ufw allow 443 &>>"$LOG_FILE"
  [ "$CONFIGURE_DBHOST" == true ]      && ufw allow 3306 &>>"$LOG_FILE"
  ufw --force enable &>>"$LOG_FILE"
  success "Firewall configured (ports 22, 8080, 2022 open)"
}

# ──────────────────────────────────────────────
#  Install Docker
# ──────────────────────────────────────────────
install_docker() {
  info "Installing Docker..."

  case "$OS" in
    ubuntu|debian)
      install_packages "ca-certificates gnupg lsb-release"
      mkdir -p /etc/apt/keyrings
      curl -fsSL https://download.docker.com/linux/$OS/gpg \
        | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg &>>"$LOG_FILE"
      echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
        https://download.docker.com/linux/$OS $(lsb_release -cs) stable" \
        | tee /etc/apt/sources.list.d/docker.list &>>"$LOG_FILE"
      update_repos
      install_packages "docker-ce docker-ce-cli containerd.io"
      ;;
    rocky|almalinux)
      install_packages "dnf-utils"
      dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo \
        &>>"$LOG_FILE"
      install_packages "docker-ce docker-ce-cli containerd.io"
      ;;
  esac

  systemctl enable docker &>>"$LOG_FILE"
  systemctl start  docker &>>"$LOG_FILE"
  success "Docker installed"
}

# ──────────────────────────────────────────────
#  Optional MariaDB for db-host feature
# ──────────────────────────────────────────────
install_mariadb() {
  info "Installing MariaDB..."
  install_packages "mariadb-server"
  systemctl enable mariadb &>>"$LOG_FILE"
  systemctl start  mariadb &>>"$LOG_FILE"
  success "MariaDB installed"
}

configure_dbhost() {
  info "Configuring MariaDB database host user..."
  mysql -u root &>>"$LOG_FILE" <<SQL
CREATE USER IF NOT EXISTS 'pterodactyluser'@'%' IDENTIFIED BY '${DBHOST_PASSWORD}';
GRANT ALL PRIVILEGES ON *.* TO 'pterodactyluser'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
SQL

  # Allow external connections if needed
  case "$OS" in
    debian|ubuntu)
      sed -i 's/^bind-address\s*=.*/bind-address = 0.0.0.0/' \
        /etc/mysql/mariadb.conf.d/50-server.cnf 2>/dev/null || true
      ;;
    rocky|almalinux)
      sed -i 's/^#bind-address=0.0.0.0/bind-address=0.0.0.0/' \
        /etc/my.cnf.d/mariadb-server.cnf 2>/dev/null || true
      ;;
  esac

  systemctl restart mariadb &>>"$LOG_FILE"
  success "Database host user 'pterodactyluser' configured"
}

# ──────────────────────────────────────────────
#  Download Wings
# ──────────────────────────────────────────────
download_wings() {
  info "Downloading Pterodactyl Wings (latest release)..."

  mkdir -p /etc/pterodactyl

  # Detect architecture
  case "$(uname -m)" in
    x86_64)  ARCH="amd64" ;;
    aarch64) ARCH="arm64" ;;
    *)       error "Unsupported architecture: $(uname -m)"; exit 1 ;;
  esac

  WINGS_VER=$(curl -fsSL https://api.github.com/repos/pterodactyl/wings/releases/latest \
    | grep '"tag_name"' | cut -d'"' -f4)

  curl -fsSL -o /usr/local/bin/wings \
    "https://github.com/pterodactyl/wings/releases/download/${WINGS_VER}/wings_linux_${ARCH}" \
    &>>"$LOG_FILE"

  chmod +x /usr/local/bin/wings
  success "Wings ${WINGS_VER} (${ARCH}) downloaded"
}

# ──────────────────────────────────────────────
#  Wings systemd service
# ──────────────────────────────────────────────
install_wings_service() {
  info "Installing Wings systemd service..."

  cat > /etc/systemd/system/wings.service <<SERVICE
[Unit]
Description=Pterodactyl Wings
After=docker.service
Requires=docker.service
PartOf=docker.service

[Service]
User=root
WorkingDirectory=/etc/pterodactyl
LimitNOFILE=4096
PIDFile=/var/run/wings/daemon.pid
ExecStart=/usr/local/bin/wings
Restart=on-failure
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
SERVICE

  systemctl daemon-reload     &>>"$LOG_FILE"
  systemctl enable wings      &>>"$LOG_FILE"
  success "Wings service installed"
}

# ──────────────────────────────────────────────
#  Let's Encrypt for Wings
# ──────────────────────────────────────────────
obtain_ssl() {
  info "Installing Certbot and obtaining SSL certificate..."

  case "$OS" in
    ubuntu|debian) install_packages "certbot" ;;
    rocky|almalinux) install_packages "epel-release certbot" ;;
  esac

  FAILED=false
  systemctl stop nginx 2>/dev/null || true

  certbot certonly --standalone --no-eff-email \
    --email "${LE_EMAIL}" \
    -d "${FQDN}" \
    --non-interactive || FAILED=true

  systemctl start nginx 2>/dev/null || true

  if [ ! -d "/etc/letsencrypt/live/${FQDN}/" ] || [ "$FAILED" == true ]; then
    warn "Let's Encrypt failed. Wings will run without SSL."
  else
    success "SSL certificate obtained for ${FQDN}"
  fi
}

print_completion() {
  echo -e ""
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  ${GREEN}${BOLD}✓ Wings Installation Complete!${NC}"
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e ""
  echo -e "  ${BOLD}Next steps:${NC}"
  echo -e "  1. Go to your Panel → Admin → Nodes → Create Node"
  echo -e "  2. Copy the config from the ${WHITE}Configuration${NC} tab"
  echo -e "  3. Paste it into: ${CYAN}/etc/pterodactyl/config.yml${NC}"
  echo -e "  4. Start Wings:   ${CYAN}systemctl start wings${NC}"
  echo -e ""
  if [ "$INSTALL_MARIADB" == true ]; then
    echo -e "  ${BOLD}DB Host User :${NC} ${WHITE}pterodactyluser${NC}"
    echo -e "  ${BOLD}DB Host Pass :${NC} ${WHITE}${DBHOST_PASSWORD}${NC}"
    echo -e ""
  fi
  echo -e "  ${DIM}Installer by XENTO — https://github.com/thexento/Pterodactyl-Installer${NC}"
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e ""
}

# ──────────────────────────────────────────────
#  Main
# ──────────────────────────────────────────────
main() {
  touch "$LOG_FILE"

  detect_os
  collect_inputs

  update_repos
  [ "$CONFIGURE_FIREWALL" == true ] && configure_firewall
  install_docker
  [ "$INSTALL_MARIADB" == true ] && install_mariadb
  [ "$CONFIGURE_DBHOST" == true ] && configure_dbhost
  download_wings
  install_wings_service
  [ "$CONFIGURE_LETSENCRYPT" == true ] && obtain_ssl

  print_completion
}

main "$@"