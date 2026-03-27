#!/bin/bash

set -e

######################################################################################
#                                                                                    #
#  Pterodactyl Installer by XENTO — phpMyAdmin Script                               #
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
PMA_VERSION="5.2.1"
PMA_DIR="/var/www/phpmyadmin"
PMA_DOWNLOAD="https://files.phpmyadmin.net/phpMyAdmin/${PMA_VERSION}/phpMyAdmin-${PMA_VERSION}-all-languages.tar.gz"

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
#  Collect all inputs
# ──────────────────────────────────────────────
collect_inputs() {
  echo -e ""
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  ${BOLD}phpMyAdmin Configuration${NC}"
  echo -e "  ${DIM}All questions are asked before installation begins.${NC}"
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e ""

  while true; do
    echo -n -e "  ${WHITE}Domain or IP for phpMyAdmin (e.g. db.example.com):${NC} "
    read -r PMA_FQDN
    if validate_fqdn "$PMA_FQDN"; then break
    else error "Invalid domain or IP."; fi
  done

  echo -e ""
  echo -e "  ${WHITE}SSL Options:${NC}"
  echo -e "    ${WHITE}[1]${NC} Use Let's Encrypt"
  echo -e "    ${WHITE}[2]${NC} No SSL (HTTP only)"
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

  # Summary
  echo -e ""
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  ${BOLD}Installation Summary${NC}"
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  phpMyAdmin URL : ${WHITE}${PMA_FQDN}${NC}"
  echo -e "  Version        : ${WHITE}${PMA_VERSION}${NC}"
  echo -e "  SSL            : ${WHITE}$([ "$CONFIGURE_LETSENCRYPT" == true ] && echo "Let's Encrypt" || echo "None")${NC}"
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
install_packages() {
  export DEBIAN_FRONTEND=noninteractive
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
#  Install phpMyAdmin
# ──────────────────────────────────────────────
download_phpmyadmin() {
  info "Downloading phpMyAdmin ${PMA_VERSION}..."
  mkdir -p "$PMA_DIR"

  curl -fsSL -o /tmp/phpmyadmin.tar.gz "$PMA_DOWNLOAD" &>>"$LOG_FILE"
  tar -xzf /tmp/phpmyadmin.tar.gz --strip-components=1 -C "$PMA_DIR" &>>"$LOG_FILE"
  rm -f /tmp/phpmyadmin.tar.gz

  # Create config with blowfish secret
  local BLOWFISH
  BLOWFISH="$(tr -dc 'A-Za-z0-9!@#$%^&*' </dev/urandom | head -c 32)"

  cp "${PMA_DIR}/config.sample.inc.php" "${PMA_DIR}/config.inc.php"
  sed -i "s|'blowfish_secret'] = ''|'blowfish_secret'] = '${BLOWFISH}'|g" \
    "${PMA_DIR}/config.inc.php"

  # Set permissions
  local WEB_USER="www-data"
  [ "$OS" == "rocky" ] || [ "$OS" == "almalinux" ] && WEB_USER="nginx"
  chown -R "${WEB_USER}:${WEB_USER}" "$PMA_DIR"

  success "phpMyAdmin downloaded to ${PMA_DIR}"
}

configure_nginx() {
  info "Configuring NGINX for phpMyAdmin..."

  local PHP_SOCKET="/run/php/php8.3-fpm.sock"
  [ "$OS" == "rocky" ] || [ "$OS" == "almalinux" ] && \
    PHP_SOCKET="/var/run/php-fpm/pterodactyl.sock"

  local CONFIG_AVAIL="/etc/nginx/sites-available"
  local CONFIG_ENABL="/etc/nginx/sites-enabled"
  if [ "$OS" == "rocky" ] || [ "$OS" == "almalinux" ]; then
    CONFIG_AVAIL="/etc/nginx/conf.d"
    CONFIG_ENABL="/etc/nginx/conf.d"
  fi

  cat > "${CONFIG_AVAIL}/phpmyadmin.conf" <<NGINX
server {
    listen 80;
    server_name ${PMA_FQDN};
    root ${PMA_DIR};
    index index.php;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:${PHP_SOCKET};
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
    }

    location ~ /\.ht { deny all; }
}
NGINX

  if [ "$OS" == "ubuntu" ] || [ "$OS" == "debian" ]; then
    ln -sf "${CONFIG_AVAIL}/phpmyadmin.conf" \
           "${CONFIG_ENABL}/phpmyadmin.conf" 2>/dev/null || true
  fi

  if [ "$CONFIGURE_LETSENCRYPT" == false ]; then
    nginx -t &>>"$LOG_FILE"
    systemctl reload nginx &>>"$LOG_FILE"
  fi

  success "NGINX configured for phpMyAdmin"
}

obtain_ssl() {
  info "Obtaining Let's Encrypt certificate for ${PMA_FQDN}..."

  case "$OS" in
    ubuntu|debian) install_packages "certbot python3-certbot-nginx" ;;
    rocky|almalinux) install_packages "epel-release certbot python3-certbot-nginx" ;;
  esac

  FAILED=false
  certbot --nginx --redirect --no-eff-email \
    --email "${LE_EMAIL}" \
    -d "${PMA_FQDN}" \
    --non-interactive || FAILED=true

  if [ ! -d "/etc/letsencrypt/live/${PMA_FQDN}/" ] || [ "$FAILED" == true ]; then
    warn "Let's Encrypt failed. phpMyAdmin is accessible via HTTP."
  else
    systemctl reload nginx &>>"$LOG_FILE"
    success "SSL certificate obtained"
  fi
}

print_completion() {
  local proto="http"
  [ "$CONFIGURE_LETSENCRYPT" == true ] && proto="https"

  echo -e ""
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  ${GREEN}${BOLD}✓ phpMyAdmin Installation Complete!${NC}"
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e ""
  echo -e "  ${BOLD}phpMyAdmin URL :${NC} ${CYAN}${proto}://${PMA_FQDN}${NC}"
  echo -e "  ${BOLD}Login with     :${NC} your MariaDB root credentials"
  echo -e ""
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
  download_phpmyadmin
  configure_nginx
  [ "$CONFIGURE_LETSENCRYPT" == true ] && obtain_ssl
  print_completion
}

main "$@"