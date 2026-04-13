#!/bin/bash

set -e

######################################################################################
#                                                                                    #
#  Pterodactyl Installer by XENTO                                                    #
#  https://github.com/thexento/Pterodactyl-Installer                                 #
#  https://pterodactyl-installer.xento.xyz                                           #
#                                                                                    #
#  Copyright (C) 2024 - 2026, XENTO                                                  #
#  Licensed under the GNU General Public License v3.0                                #
#  https://www.gnu.org/licenses/gpl-3.0                                              #
#                                                                                    #
#  This script is not associated with the official Pterodactyl Project.              #
#                                                                                    #
######################################################################################

SCRIPT_VERSION="v1.0.0"
LOG_FILE="/var/log/pterodactyl-xento.log"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[ OK ]${NC}  $*" | tee -a "$LOG_FILE"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*" | tee -a "$LOG_FILE"; }
error()   { echo -e "${RED}[ERR ]${NC}  $*" | tee -a "$LOG_FILE" >&2; }

###############################################################################
# HEADER
###############################################################################

print_header() {
  clear
  echo -e ""
  echo -e "${CYAN}${BOLD}  ██╗  ██╗███████╗███╗   ██╗████████╗ ██████╗ ${NC}"
  echo -e "${CYAN}${BOLD}  ╚██╗██╔╝██╔════╝████╗  ██║╚══██╔══╝██╔═══██╗${NC}"
  echo -e "${CYAN}${BOLD}   ╚███╔╝ █████╗  ██╔██╗ ██║   ██║   ██║   ██║${NC}"
  echo -e "${CYAN}${BOLD}   ██╔██╗ ██╔══╝  ██║╚██╗██║   ██║   ██║   ██║${NC}"
  echo -e "${CYAN}${BOLD}  ██╔╝ ██╗███████╗██║ ╚████║   ██║   ╚██████╔╝${NC}"
  echo -e "${CYAN}${BOLD}  ╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝   ╚═╝    ╚═════╝ ${NC}"
  echo -e ""
  echo -e "  ${WHITE}${BOLD}Welcome to the Pterodactyl Installer — by XENTO${NC}"
  echo -e "  ${DIM}https://github.com/thexento/Pterodactyl-Installer${NC}"
  echo -e "  ${DIM}pterodactyl-installer.xento.xyz  |  ${SCRIPT_VERSION}${NC}"
  echo -e ""
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e ""
}

###############################################################################
# PREFLIGHT
###############################################################################

require_root() {
  if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root."
    error "Try: sudo bash install.sh"
    exit 1
  fi
}

check_deps() {
  export DEBIAN_FRONTEND=noninteractive
  for dep in curl wget tar git; do
    if ! command -v "$dep" &>/dev/null; then
      info "Installing missing dependency: $dep"
      apt-get update -y &>>"$LOG_FILE"
      apt-get install -y "$dep" &>>"$LOG_FILE"
    fi
  done
}

detect_os() {
  if [ -f /etc/os-release ]; then
    # shellcheck source=/dev/null
    source /etc/os-release
    OS="$ID"
    OS_VER="$VERSION_ID"
    OS_VER_MAJOR="${VERSION_ID%%.*}"
  else
    error "Cannot detect OS. Supported: Ubuntu 20/22/24, Debian 11/12."
    exit 1
  fi

  case "$OS" in
    ubuntu)
      case "$OS_VER" in
        20.04|22.04|24.04) ;;
        *) error "Unsupported Ubuntu version: $OS_VER (supported: 20.04, 22.04, 24.04)"; exit 1 ;;
      esac
      ;;
    debian)
      case "$OS_VER" in
        11|12) ;;
        *) error "Unsupported Debian version: $OS_VER (supported: 11, 12)"; exit 1 ;;
      esac
      ;;
    *)
      error "Unsupported OS: $OS. Only Ubuntu and Debian are supported."
      exit 1
      ;;
  esac

  success "Detected OS: $OS $OS_VER"
}

###############################################################################
# VALIDATION HELPERS
###############################################################################

validate_email() {
  [[ "$1" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]
}

validate_fqdn() {
  [[ "$1" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]] || \
  [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

###############################################################################
# MAIN MENU
###############################################################################

main_menu() {
  echo -e "  ${BOLD}What would you like to do?${NC}\n"
  echo -e "  ${WHITE}[1]${NC} Install Panel"
  echo -e "  ${WHITE}[2]${NC} Install Wings"
  echo -e "  ${WHITE}[3]${NC} Install Panel + Wings (same machine)"
  echo -e "  ${WHITE}[4]${NC} Uninstall Panel / Wings"
  echo -e ""
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e ""

  while true; do
    echo -n -e "  ${WHITE}Choice [1-4]:${NC} "
    read -r MENU_CHOICE
    case "$MENU_CHOICE" in
      1|2|3|4) break ;;
      *) error "Invalid option. Enter 1, 2, 3, or 4." ;;
    esac
  done
}

###############################################################################
# PACKAGE HELPERS
###############################################################################

update_repos() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y &>>"$LOG_FILE"
}

install_packages() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get install -y $@ &>>"$LOG_FILE"
}

###############################################################################
# PANEL — INPUT COLLECTION
###############################################################################

collect_panel_inputs() {
  echo -e ""
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  ${BOLD}Panel Configuration${NC}"
  echo -e "  ${DIM}All questions are asked before installation begins.${NC}"
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e ""

  while true; do
    echo -n -e "  ${WHITE}Panel domain or IP (e.g. panel.example.com):${NC} "
    read -r PANEL_FQDN
    if validate_fqdn "$PANEL_FQDN"; then break
    else error "Invalid domain or IP address. Try again."; fi
  done

  while true; do
    echo -n -e "  ${WHITE}Admin email address:${NC} "
    read -r ADMIN_EMAIL
    if validate_email "$ADMIN_EMAIL"; then break
    else error "Invalid email address. Try again."; fi
  done

  while true; do
    echo -n -e "  ${WHITE}Admin username (min 3 characters):${NC} "
    read -r ADMIN_USERNAME
    [[ -n "$ADMIN_USERNAME" && ${#ADMIN_USERNAME} -ge 3 ]] && break
    error "Username must be at least 3 characters."
  done

  while true; do
    echo -n -e "  ${WHITE}Admin first name:${NC} "
    read -r ADMIN_FIRSTNAME
    [[ -n "$ADMIN_FIRSTNAME" ]] && break
    error "First name cannot be empty."
  done

  while true; do
    echo -n -e "  ${WHITE}Admin last name:${NC} "
    read -r ADMIN_LASTNAME
    [[ -n "$ADMIN_LASTNAME" ]] && break
    error "Last name cannot be empty."
  done

  while true; do
    echo -n -e "  ${WHITE}Admin password (min 8 characters):${NC} "
    read -rs ADMIN_PASSWORD
    echo ""
    [[ ${#ADMIN_PASSWORD} -ge 8 ]] && break
    error "Password must be at least 8 characters."
  done

  echo -n -e "  ${WHITE}Timezone (default: UTC):${NC} "
  read -r TIMEZONE
  TIMEZONE="${TIMEZONE:-UTC}"

  echo -e ""
  echo -e "  ${WHITE}SSL:${NC}"
  echo -e "    ${WHITE}[1]${NC} Let's Encrypt (auto SSL — requires a valid domain)"
  echo -e "    ${WHITE}[2]${NC} Assume SSL (custom cert / reverse proxy already set up)"
  echo -e "    ${WHITE}[3]${NC} No SSL (HTTP only)"
  while true; do
    echo -n -e "  ${WHITE}SSL choice [1-3]:${NC} "
    read -r SSL_CHOICE
    case "$SSL_CHOICE" in
      1) PANEL_LETSENCRYPT=true;  PANEL_ASSUME_SSL=false; break ;;
      2) PANEL_LETSENCRYPT=false; PANEL_ASSUME_SSL=true;  break ;;
      3) PANEL_LETSENCRYPT=false; PANEL_ASSUME_SSL=false; break ;;
      *) error "Enter 1, 2, or 3." ;;
    esac
  done

  echo -e ""
  while true; do
    echo -n -e "  ${WHITE}Configure UFW firewall automatically? [y/N]:${NC} "
    read -r FW_INPUT
    case "$FW_INPUT" in
      [Yy]*) PANEL_FIREWALL=true;  break ;;
      [Nn]*|"") PANEL_FIREWALL=false; break ;;
      *) error "Enter y or n." ;;
    esac
  done

  MYSQL_DB="panel"
  MYSQL_USER="pterodactyl"
  MYSQL_PASSWORD="$(tr -dc 'A-Za-z0-9!@#%^&*' </dev/urandom | head -c 32)"

  # Summary
  echo -e ""
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  ${BOLD}Summary — Panel${NC}"
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  Domain      : ${WHITE}${PANEL_FQDN}${NC}"
  echo -e "  Admin Email : ${WHITE}${ADMIN_EMAIL}${NC}"
  echo -e "  Username    : ${WHITE}${ADMIN_USERNAME}${NC}"
  echo -e "  Full Name   : ${WHITE}${ADMIN_FIRSTNAME} ${ADMIN_LASTNAME}${NC}"
  echo -e "  Timezone    : ${WHITE}${TIMEZONE}${NC}"
  if [ "$PANEL_LETSENCRYPT" == true ]; then
    echo -e "  SSL         : ${WHITE}Let's Encrypt${NC}"
  elif [ "$PANEL_ASSUME_SSL" == true ]; then
    echo -e "  SSL         : ${WHITE}Assume SSL${NC}"
  else
    echo -e "  SSL         : ${WHITE}None (HTTP)${NC}"
  fi
  echo -e "  Firewall    : ${WHITE}$([ "$PANEL_FIREWALL" == true ] && echo "Yes" || echo "No")${NC}"
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e ""

  while true; do
    echo -n -e "  ${WHITE}Confirm and begin installation? [y/N]:${NC} "
    read -r CONFIRM
    case "$CONFIRM" in
      [Yy]*) break ;;
      [Nn]*|"") error "Installation cancelled."; exit 0 ;;
      *) error "Enter y or n." ;;
    esac
  done
  echo -e ""
}

###############################################################################
# PANEL — INSTALLATION
###############################################################################

panel_add_repos() {
  info "Adding PHP repositories..."
  case "$OS" in
    ubuntu)
      install_packages "software-properties-common apt-transport-https ca-certificates gnupg"
      add-apt-repository universe -y &>>"$LOG_FILE"
      LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php &>>"$LOG_FILE"
      ;;
    debian)
      install_packages "dirmngr ca-certificates apt-transport-https lsb-release"
      curl -fsSL https://packages.sury.org/php/apt.gpg \
        -o /etc/apt/trusted.gpg.d/php.gpg 2>>"$LOG_FILE"
      echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" \
        | tee /etc/apt/sources.list.d/php.list &>>"$LOG_FILE"
      ;;
  esac
  update_repos
  success "Repositories added"
}

panel_install_deps() {
  info "Installing system dependencies (PHP, MariaDB, NGINX, Redis)..."
  install_packages \
    "php8.3 php8.3-cli php8.3-common php8.3-gd php8.3-mysql php8.3-mbstring \
     php8.3-bcmath php8.3-xml php8.3-fpm php8.3-curl php8.3-zip \
     mariadb-common mariadb-server mariadb-client \
     nginx redis-server \
     zip unzip tar git cron curl wget"

  [ "$PANEL_LETSENCRYPT" == true ] && install_packages "certbot python3-certbot-nginx"
  success "Dependencies installed"
}

panel_enable_services() {
  info "Enabling services..."
  systemctl enable redis-server &>>"$LOG_FILE" && systemctl start redis-server &>>"$LOG_FILE"
  systemctl enable nginx        &>>"$LOG_FILE"
  systemctl enable mariadb      &>>"$LOG_FILE" && systemctl start mariadb      &>>"$LOG_FILE"
  success "Services enabled"
}

panel_firewall() {
  info "Configuring UFW firewall..."
  install_packages "ufw"
  ufw allow 22  &>>"$LOG_FILE"
  ufw allow 80  &>>"$LOG_FILE"
  ufw allow 443 &>>"$LOG_FILE"
  ufw --force enable &>>"$LOG_FILE"
  success "Firewall configured (22, 80, 443)"
}

panel_install_composer() {
  info "Installing Composer..."
  curl -sS https://getcomposer.org/installer \
    | php -- --install-dir=/usr/local/bin --filename=composer &>>"$LOG_FILE"
  success "Composer installed"
}

panel_setup_db() {
  info "Setting up MariaDB database and user..."
  mysql -u root &>>"$LOG_FILE" <<SQL
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DB}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'127.0.0.1' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DB}\`.* TO '${MYSQL_USER}'@'127.0.0.1' WITH GRANT OPTION;
FLUSH PRIVILEGES;
SQL
  success "Database '${MYSQL_DB}' and user '${MYSQL_USER}' created"
}

panel_download() {
  info "Downloading Pterodactyl Panel (latest)..."
  mkdir -p /var/www/pterodactyl
  cd /var/www/pterodactyl

  PANEL_VER=$(curl -fsSL https://api.github.com/repos/pterodactyl/panel/releases/latest \
    | grep '"tag_name"' | cut -d'"' -f4)
  curl -fsSL -o panel.tar.gz \
    "https://github.com/pterodactyl/panel/releases/download/${PANEL_VER}/panel.tar.gz" \
    &>>"$LOG_FILE"
  tar -xzf panel.tar.gz &>>"$LOG_FILE"
  rm -f panel.tar.gz
  chmod -R 755 storage/* bootstrap/cache/
  cp .env.example .env
  success "Panel ${PANEL_VER} downloaded"
}

panel_composer_deps() {
  info "Installing Composer dependencies (this may take a few minutes)..."
  cd /var/www/pterodactyl
  COMPOSER_ALLOW_SUPERUSER=1 composer install \
    --no-dev --optimize-autoloader --no-interaction &>>"$LOG_FILE"
  success "Composer dependencies installed"
}

panel_configure() {
  info "Configuring Panel environment..."
  cd /var/www/pterodactyl

  local app_url="http://${PANEL_FQDN}"
  [ "$PANEL_ASSUME_SSL"    == true ] && app_url="https://${PANEL_FQDN}"
  [ "$PANEL_LETSENCRYPT"   == true ] && app_url="https://${PANEL_FQDN}"

  php artisan key:generate --force &>>"$LOG_FILE"

  php artisan p:environment:setup \
    --author="${ADMIN_EMAIL}" \
    --url="${app_url}" \
    --timezone="${TIMEZONE}" \
    --cache="redis" \
    --session="redis" \
    --queue="redis" \
    --redis-host="127.0.0.1" \
    --redis-pass="null" \
    --redis-port="6379" \
    --settings-ui=true \
    --no-interaction \
    &>>"$LOG_FILE"

  php artisan p:environment:database \
    --host="127.0.0.1" \
    --port="3306" \
    --database="${MYSQL_DB}" \
    --username="${MYSQL_USER}" \
    --password="${MYSQL_PASSWORD}" \
    --no-interaction \
    &>>"$LOG_FILE"

  php artisan migrate --seed --force &>>"$LOG_FILE"

  php artisan p:user:make \
    --email="${ADMIN_EMAIL}" \
    --username="${ADMIN_USERNAME}" \
    --name-first="${ADMIN_FIRSTNAME}" \
    --name-last="${ADMIN_LASTNAME}" \
    --password="${ADMIN_PASSWORD}" \
    --admin=1 \
    --no-interaction \
    &>>"$LOG_FILE"

  chown -R www-data:www-data /var/www/pterodactyl
  success "Panel configured and admin user created"
}

panel_cron() {
  info "Installing cron job..."
  (crontab -l 2>/dev/null; \
    echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1") \
    | crontab -
  success "Cron job installed"
}

panel_queue_worker() {
  info "Installing pteroq queue worker service..."
  cat > /etc/systemd/system/pteroq.service <<SERVICE
[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service

[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
SERVICE
  systemctl daemon-reload &>>"$LOG_FILE"
  systemctl enable pteroq &>>"$LOG_FILE"
  systemctl start  pteroq &>>"$LOG_FILE"
  success "pteroq service installed and running"
}

panel_nginx() {
  info "Configuring NGINX..."

  local PHP_SOCKET="/run/php/php8.3-fpm.sock"
  rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true

  if [ "$PANEL_ASSUME_SSL" == true ]; then
    cat > /etc/nginx/sites-available/pterodactyl.conf <<NGINX
server {
    listen 80;
    server_name ${PANEL_FQDN};
    return 301 https://\$host\$request_uri;
}
server {
    listen 443 ssl http2;
    server_name ${PANEL_FQDN};
    root /var/www/pterodactyl/public;
    index index.php;
    ssl_certificate /etc/letsencrypt/live/${PANEL_FQDN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${PANEL_FQDN}/privkey.pem;
    ssl_session_cache shared:SSL:10m;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers on;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Robots-Tag none;
    add_header Content-Security-Policy "frame-ancestors 'self'";
    add_header X-Frame-Options DENY;
    add_header Referrer-Policy same-origin;
    location / { try_files \$uri \$uri/ /index.php?\$query_string; }
    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:${PHP_SOCKET};
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param PHP_VALUE "upload_max_filesize = 100M \n post_max_size = 100M";
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
    }
    location ~ /\.ht { deny all; }
}
NGINX
  else
    cat > /etc/nginx/sites-available/pterodactyl.conf <<NGINX
server {
    listen 80;
    server_name ${PANEL_FQDN};
    root /var/www/pterodactyl/public;
    index index.php;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Robots-Tag none;
    add_header X-Frame-Options DENY;
    add_header Referrer-Policy same-origin;
    location / { try_files \$uri \$uri/ /index.php?\$query_string; }
    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:${PHP_SOCKET};
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param PHP_VALUE "upload_max_filesize = 100M \n post_max_size = 100M";
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
    }
    location ~ /\.ht { deny all; }
}
NGINX
  fi

  ln -sf /etc/nginx/sites-available/pterodactyl.conf \
         /etc/nginx/sites-enabled/pterodactyl.conf 2>/dev/null || true

  if [ "$PANEL_LETSENCRYPT" == false ]; then
    nginx -t &>>"$LOG_FILE"
    systemctl restart nginx &>>"$LOG_FILE"
  fi

  success "NGINX configured"
}

panel_ssl() {
  info "Obtaining Let's Encrypt certificate for ${PANEL_FQDN}..."
  local FAILED=false

  certbot --nginx --redirect --no-eff-email \
    --email "${ADMIN_EMAIL}" \
    -d "${PANEL_FQDN}" \
    --non-interactive &>>"$LOG_FILE" || FAILED=true

  if [ ! -d "/etc/letsencrypt/live/${PANEL_FQDN}/" ] || [ "$FAILED" == true ]; then
    warn "Let's Encrypt failed. Panel is accessible via HTTP."
    PANEL_LETSENCRYPT=false
  else
    systemctl restart nginx &>>"$LOG_FILE"
    success "SSL certificate obtained"
  fi
}

panel_print_done() {
  local proto="http"
  [ "$PANEL_LETSENCRYPT" == true ] && proto="https"
  [ "$PANEL_ASSUME_SSL"  == true ] && proto="https"

  echo -e ""
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  ${GREEN}${BOLD}✓ Panel Installation Complete!${NC}"
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e ""
  echo -e "  ${BOLD}Panel URL   :${NC} ${CYAN}${proto}://${PANEL_FQDN}${NC}"
  echo -e "  ${BOLD}Username    :${NC} ${WHITE}${ADMIN_USERNAME}${NC}"
  echo -e "  ${BOLD}Email       :${NC} ${WHITE}${ADMIN_EMAIL}${NC}"
  echo -e "  ${BOLD}DB Password :${NC} ${WHITE}${MYSQL_PASSWORD}${NC}"
  echo -e ""
}

install_panel() {
  collect_panel_inputs
  panel_add_repos
  install_packages "ca-certificates gnupg lsb-release"
  panel_install_deps
  panel_enable_services
  [ "$PANEL_FIREWALL" == true ] && panel_firewall
  panel_install_composer
  panel_setup_db
  panel_download
  panel_composer_deps
  panel_configure
  panel_cron
  panel_queue_worker
  panel_nginx
  [ "$PANEL_LETSENCRYPT" == true ] && panel_ssl
  panel_print_done
}

###############################################################################
# WINGS — INPUT COLLECTION
###############################################################################

collect_wings_inputs() {
  echo -e ""
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  ${BOLD}Wings Configuration${NC}"
  echo -e "  ${DIM}All questions are asked before installation begins.${NC}"
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e ""

  while true; do
    echo -n -e "  ${WHITE}Wings FQDN or IP (this server):${NC} "
    read -r WINGS_FQDN
    if validate_fqdn "$WINGS_FQDN"; then break
    else error "Invalid domain or IP. Try again."; fi
  done

  while true; do
    echo -n -e "  ${WHITE}Install MariaDB for database host feature? [y/N]:${NC} "
    read -r DB_INPUT
    case "$DB_INPUT" in
      [Yy]*) WINGS_INSTALL_DB=true;  break ;;
      [Nn]*|"") WINGS_INSTALL_DB=false; break ;;
      *) error "Enter y or n." ;;
    esac
  done

  if [ "$WINGS_INSTALL_DB" == true ]; then
    while true; do
      echo -n -e "  ${WHITE}Database host user password (min 8 chars):${NC} "
      read -rs WINGS_DB_PASSWORD
      echo ""
      [[ ${#WINGS_DB_PASSWORD} -ge 8 ]] && break
      error "Password must be at least 8 characters."
    done
  fi

  echo -e ""
  echo -e "  ${WHITE}SSL:${NC}"
  echo -e "    ${WHITE}[1]${NC} Let's Encrypt (requires valid domain)"
  echo -e "    ${WHITE}[2]${NC} No SSL"
  while true; do
    echo -n -e "  ${WHITE}SSL choice [1-2]:${NC} "
    read -r SSL_CHOICE
    case "$SSL_CHOICE" in
      1) WINGS_LETSENCRYPT=true;  break ;;
      2) WINGS_LETSENCRYPT=false; break ;;
      *) error "Enter 1 or 2." ;;
    esac
  done

  if [ "$WINGS_LETSENCRYPT" == true ]; then
    while true; do
      echo -n -e "  ${WHITE}Email for Let's Encrypt:${NC} "
      read -r WINGS_LE_EMAIL
      if validate_email "$WINGS_LE_EMAIL"; then break
      else error "Invalid email."; fi
    done
  fi

  echo -e ""
  while true; do
    echo -n -e "  ${WHITE}Configure UFW firewall? [y/N]:${NC} "
    read -r FW_INPUT
    case "$FW_INPUT" in
      [Yy]*) WINGS_FIREWALL=true;  break ;;
      [Nn]*|"") WINGS_FIREWALL=false; break ;;
      *) error "Enter y or n." ;;
    esac
  done

  # Summary
  echo -e ""
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  ${BOLD}Summary — Wings${NC}"
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  FQDN/IP   : ${WHITE}${WINGS_FQDN}${NC}"
  echo -e "  MariaDB   : ${WHITE}$([ "$WINGS_INSTALL_DB" == true ] && echo "Yes" || echo "No")${NC}"
  echo -e "  SSL       : ${WHITE}$([ "$WINGS_LETSENCRYPT" == true ] && echo "Let's Encrypt" || echo "None")${NC}"
  echo -e "  Firewall  : ${WHITE}$([ "$WINGS_FIREWALL" == true ] && echo "Yes" || echo "No")${NC}"
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e ""

  while true; do
    echo -n -e "  ${WHITE}Confirm and begin installation? [y/N]:${NC} "
    read -r CONFIRM
    case "$CONFIRM" in
      [Yy]*) break ;;
      [Nn]*|"") error "Installation cancelled."; exit 0 ;;
      *) error "Enter y or n." ;;
    esac
  done
  echo -e ""
}

###############################################################################
# WINGS — INSTALLATION
###############################################################################

wings_firewall() {
  info "Configuring UFW firewall..."
  install_packages "ufw"
  ufw allow 22   &>>"$LOG_FILE"
  ufw allow 8080 &>>"$LOG_FILE"
  ufw allow 2022 &>>"$LOG_FILE"
  [ "$WINGS_LETSENCRYPT" == true ] && ufw allow 80 &>>"$LOG_FILE" && ufw allow 443 &>>"$LOG_FILE"
  [ "$WINGS_INSTALL_DB"  == true ] && ufw allow 3306 &>>"$LOG_FILE"
  ufw --force enable &>>"$LOG_FILE"
  success "Firewall configured (22, 8080, 2022)"
}

wings_install_docker() {
  info "Installing Docker..."
  install_packages "ca-certificates gnupg lsb-release"
  mkdir -p /etc/apt/keyrings
  curl -fsSL "https://download.docker.com/linux/${OS}/gpg" \
    | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg 2>>"$LOG_FILE"
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/${OS} $(lsb_release -cs) stable" \
    | tee /etc/apt/sources.list.d/docker.list &>>"$LOG_FILE"
  update_repos
  install_packages "docker-ce docker-ce-cli containerd.io"
  systemctl enable docker &>>"$LOG_FILE"
  systemctl start  docker &>>"$LOG_FILE"
  success "Docker installed"
}

wings_install_mariadb() {
  info "Installing MariaDB..."
  install_packages "mariadb-server"
  systemctl enable mariadb &>>"$LOG_FILE"
  systemctl start  mariadb &>>"$LOG_FILE"

  info "Configuring database host user..."
  mysql -u root &>>"$LOG_FILE" <<SQL
CREATE USER IF NOT EXISTS 'pterodactyluser'@'%' IDENTIFIED BY '${WINGS_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON *.* TO 'pterodactyluser'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
SQL
  sed -i 's/^bind-address\s*=.*/bind-address = 0.0.0.0/' \
    /etc/mysql/mariadb.conf.d/50-server.cnf 2>/dev/null || true
  systemctl restart mariadb &>>"$LOG_FILE"
  success "MariaDB installed and database host user configured"
}

wings_download() {
  info "Downloading Pterodactyl Wings (latest)..."
  mkdir -p /etc/pterodactyl

  case "$(uname -m)" in
    x86_64)  ARCH="amd64" ;;
    aarch64) ARCH="arm64" ;;
    *) error "Unsupported architecture: $(uname -m)"; exit 1 ;;
  esac

  WINGS_VER=$(curl -fsSL https://api.github.com/repos/pterodactyl/wings/releases/latest \
    | grep '"tag_name"' | cut -d'"' -f4)

  curl -fsSL -o /usr/local/bin/wings \
    "https://github.com/pterodactyl/wings/releases/download/${WINGS_VER}/wings_linux_${ARCH}" \
    &>>"$LOG_FILE"
  chmod +x /usr/local/bin/wings
  success "Wings ${WINGS_VER} (${ARCH}) downloaded"
}

wings_service() {
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
  systemctl daemon-reload &>>"$LOG_FILE"
  systemctl enable wings  &>>"$LOG_FILE"
  success "Wings service installed (not started — needs config.yml first)"
}

wings_ssl() {
  info "Obtaining Let's Encrypt certificate for ${WINGS_FQDN}..."
  install_packages "certbot"
  local FAILED=false
  certbot certonly --standalone --no-eff-email \
    --email "${WINGS_LE_EMAIL}" \
    -d "${WINGS_FQDN}" \
    --non-interactive &>>"$LOG_FILE" || FAILED=true

  if [ ! -d "/etc/letsencrypt/live/${WINGS_FQDN}/" ] || [ "$FAILED" == true ]; then
    warn "Let's Encrypt failed. Wings will run without SSL."
  else
    success "SSL certificate obtained for ${WINGS_FQDN}"
  fi
}

wings_print_done() {
  echo -e ""
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  ${GREEN}${BOLD}✓ Wings Installation Complete!${NC}"
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e ""
  echo -e "  ${BOLD}Next steps:${NC}"
  echo -e "  1. Log in to your Panel"
  echo -e "  2. Go to ${WHITE}Admin → Nodes → Create Node${NC}"
  echo -e "  3. Open the ${WHITE}Configuration${NC} tab and copy the YAML"
  echo -e "  4. Paste it into: ${CYAN}/etc/pterodactyl/config.yml${NC}"
  echo -e "  5. Run: ${CYAN}systemctl start wings${NC}"
  echo -e ""
  if [ "$WINGS_INSTALL_DB" == true ]; then
    echo -e "  ${BOLD}DB Host User :${NC} ${WHITE}pterodactyluser${NC}"
    echo -e "  ${BOLD}DB Host Pass :${NC} ${WHITE}${WINGS_DB_PASSWORD}${NC}"
    echo -e ""
  fi
}

install_wings() {
  collect_wings_inputs
  update_repos
  [ "$WINGS_FIREWALL"    == true ] && wings_firewall
  wings_install_docker
  [ "$WINGS_INSTALL_DB"  == true ] && wings_install_mariadb
  wings_download
  wings_service
  [ "$WINGS_LETSENCRYPT" == true ] && wings_ssl
  wings_print_done
}

###############################################################################
# UNINSTALL — INPUT COLLECTION + EXECUTION
###############################################################################

run_uninstall() {
  echo -e ""
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  ${BOLD}${RED}Uninstaller${NC}"
  echo -e "  ${DIM}This permanently removes selected components.${NC}"
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e ""

  local RM_PANEL=false RM_WINGS=false

  while true; do
    echo -n -e "  ${WHITE}Remove Panel? [y/N]:${NC} "
    read -r INPUT
    case "$INPUT" in
      [Yy]*) RM_PANEL=true;  break ;;
      [Nn]*|"") RM_PANEL=false; break ;;
      *) error "Enter y or n." ;;
    esac
  done

  while true; do
    echo -n -e "  ${WHITE}Remove Wings? [y/N]:${NC} "
    read -r INPUT
    case "$INPUT" in
      [Yy]*) RM_WINGS=true;  break ;;
      [Nn]*|"") RM_WINGS=false; break ;;
      *) error "Enter y or n." ;;
    esac
  done

  if [ "$RM_PANEL" == false ] && [ "$RM_WINGS" == false ]; then
    warn "Nothing selected. Exiting."
    exit 0
  fi

  echo -e ""
  echo -e "  ${RED}${BOLD}⚠  This is IRREVERSIBLE.${NC}"
  echo -e "  Remove Panel : ${WHITE}$([ "$RM_PANEL" == true ] && echo "YES" || echo "No")${NC}"
  echo -e "  Remove Wings : ${WHITE}$([ "$RM_WINGS" == true ] && echo "YES" || echo "No")${NC}"
  echo -e ""

  while true; do
    echo -n -e "  ${RED}Type 'yes' to confirm:${NC} "
    read -r CONFIRM
    [ "$CONFIRM" == "yes" ] && break
    error "Type exactly 'yes' to confirm, or Ctrl+C to cancel."
  done
  echo -e ""

  if [ "$RM_PANEL" == true ]; then
    info "Removing Panel files..."
    rm -rf /var/www/pterodactyl /usr/local/bin/composer
    [ -L /etc/nginx/sites-enabled/pterodactyl.conf ]  && unlink /etc/nginx/sites-enabled/pterodactyl.conf  || true
    [ -f /etc/nginx/sites-available/pterodactyl.conf ] && rm -f  /etc/nginx/sites-available/pterodactyl.conf || true
    systemctl restart nginx 2>/dev/null || true
    success "Panel files removed"

    info "Removing cron job..."
    crontab -l 2>/dev/null \
      | grep -vF "php /var/www/pterodactyl/artisan schedule:run" \
      | crontab - || true
    success "Cron job removed"

    info "Removing Panel services..."
    systemctl disable --now pteroq 2>/dev/null || true
    rm -f /etc/systemd/system/pteroq.service
    systemctl disable --now redis-server 2>/dev/null || true
    systemctl daemon-reload
    success "Panel services removed"

    info "Removing database..."
    local valid_db
    valid_db=$(mysql -u root -e \
      "SELECT schema_name FROM information_schema.schemata;" 2>/dev/null \
      | grep -v -E 'schema_name|information_schema|performance_schema|mysql|sys' || true)

    if [[ -n "$valid_db" ]]; then
      local DATABASE=""
      echo "$valid_db" | grep -q "^panel$" && DATABASE="panel"
      if [[ -z "$DATABASE" ]]; then
        echo -e "  Databases found: ${WHITE}${valid_db}${NC}"
        echo -n -e "  ${WHITE}Enter database name to remove (blank to skip):${NC} "
        read -r DATABASE
      else
        echo -n -e "  ${WHITE}Remove database 'panel'? [y/N]:${NC} "
        read -r CONFIRM_DB
        [[ ! "$CONFIRM_DB" =~ [Yy] ]] && DATABASE=""
      fi
      if [[ -n "$DATABASE" ]]; then
        mysql -u root -e "DROP DATABASE IF EXISTS \`${DATABASE}\`;" 2>>"$LOG_FILE" || true
        success "Database '${DATABASE}' removed"
      fi

      local valid_users
      valid_users=$(mysql -u root -e "SELECT user FROM mysql.user;" 2>/dev/null \
        | grep -v -E '^(user|root|mysql|mariadb\.sys)$' || true)
      local DB_USER=""
      echo "$valid_users" | grep -q "^pterodactyl$" && DB_USER="pterodactyl"
      if [[ -n "$DB_USER" ]]; then
        echo -n -e "  ${WHITE}Remove DB user 'pterodactyl'? [y/N]:${NC} "
        read -r CONFIRM_USER
        [[ ! "$CONFIRM_USER" =~ [Yy] ]] && DB_USER=""
      fi
      if [[ -n "$DB_USER" ]]; then
        mysql -u root -e "DROP USER IF EXISTS '${DB_USER}'@'127.0.0.1';" 2>>"$LOG_FILE" || true
        mysql -u root -e "FLUSH PRIVILEGES;" 2>>"$LOG_FILE" || true
        success "DB user '${DB_USER}' removed"
      fi
    else
      info "No removable databases found"
    fi
  fi

  if [ "$RM_WINGS" == true ]; then
    info "Removing Docker containers and images..."
    command -v docker &>/dev/null && docker system prune -a -f &>>"$LOG_FILE" || true
    success "Docker containers removed"

    info "Removing Wings files..."
    systemctl disable --now wings 2>/dev/null || true
    rm -f /etc/systemd/system/wings.service
    rm -rf /etc/pterodactyl /usr/local/bin/wings /var/lib/pterodactyl
    systemctl daemon-reload
    success "Wings files removed"
  fi

  echo -e ""
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  ${GREEN}${BOLD}✓ Uninstall Complete${NC}"
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  ${DIM}Note: PHP, NGINX, MariaDB, Redis, Docker were not removed.${NC}"
  echo -e "  ${DIM}Remove them manually if no longer needed.${NC}"
  echo -e ""
}

###############################################################################
# ENTRY POINT
###############################################################################

main() {
  touch "$LOG_FILE"
  echo "=== Pterodactyl Installer by XENTO — $(date) ===" >> "$LOG_FILE"

  print_header
  require_root
  detect_os
  check_deps

  main_menu

  case "$MENU_CHOICE" in
    1)
      install_panel
      ;;
    2)
      install_wings
      ;;
    3)
      install_panel
      echo -e ""
      echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
      info "Panel done. Now configuring Wings on the same machine..."
      echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
      echo -e ""
      install_wings
      ;;
    4)
      run_uninstall
      ;;
  esac

  echo -e "  ${DIM}Log file: ${LOG_FILE}${NC}"
  echo -e "  ${DIM}Installer by XENTO — https://github.com/thexento/Pterodactyl-Installer${NC}"
  echo -e ""
}

main "$@"