#!/bin/bash

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

# Exit on unhandled errors, but we handle errors ourselves per-step
set -o pipefail

SCRIPT_VERSION="v1.0.0"
LOG_FILE="/var/log/pterodactyl-xento.log"

# Composer is installed to /usr/local/bin — make sure it's always in PATH
export PATH="/usr/local/bin:$PATH"
export DEBIAN_FRONTEND=noninteractive

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
error()   { echo -e "${RED}[ERR ]${NC}  $*" | tee -a "$LOG_FILE"; }

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
    error "This script must be run as root. Try: sudo bash install.sh"
    exit 1
  fi
}

detect_os() {
  if [ ! -f /etc/os-release ]; then
    error "Cannot detect OS. Supported: Ubuntu 20.04/22.04/24.04, Debian 11/12."
    exit 1
  fi
  # shellcheck source=/dev/null
  source /etc/os-release
  OS="$ID"
  OS_VER="$VERSION_ID"

  case "$OS" in
    ubuntu)
      case "$OS_VER" in
        20.04|22.04|24.04) ;;
        *) error "Unsupported Ubuntu version: $OS_VER"; exit 1 ;;
      esac
      ;;
    debian)
      case "$OS_VER" in
        11|12) ;;
        *) error "Unsupported Debian version: $OS_VER"; exit 1 ;;
      esac
      ;;
    *)
      error "Unsupported OS: $OS. Only Ubuntu and Debian are supported."
      exit 1
      ;;
  esac
  success "Detected OS: $OS $OS_VER"
}

bootstrap_deps() {
  info "Updating package lists..."
  apt-get update -y >> "$LOG_FILE" 2>&1
  info "Installing base dependencies..."
  apt-get install -y \
    curl wget tar git zip unzip \
    ca-certificates gnupg lsb-release \
    apt-transport-https software-properties-common \
    >> "$LOG_FILE" 2>&1
  success "Base dependencies ready"
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
    validate_fqdn "$PANEL_FQDN" && break || error "Invalid domain or IP. Try again."
  done

  while true; do
    echo -n -e "  ${WHITE}Admin email address:${NC} "
    read -r ADMIN_EMAIL
    validate_email "$ADMIN_EMAIL" && break || error "Invalid email address. Try again."
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
  echo -e "  ${WHITE}SSL Options:${NC}"
  echo -e "    ${WHITE}[1]${NC} Let's Encrypt (auto SSL — domain must point to this server)"
  echo -e "    ${WHITE}[2]${NC} Assume SSL (Cloudflare Tunnel / reverse proxy)"
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
    echo -n -e "  ${WHITE}Configure UFW firewall? [y/N]:${NC} "
    read -r FW_INPUT
    case "$FW_INPUT" in
      [Yy]*) PANEL_FIREWALL=true;  break ;;
      [Nn]*|"") PANEL_FIREWALL=false; break ;;
      *) error "Enter y or n." ;;
    esac
  done

  # Generate a secure random DB password
  MYSQL_DB="panel"
  MYSQL_USER="pterodactyl"
  MYSQL_PASSWORD="$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32)"

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
  if   [ "$PANEL_LETSENCRYPT" == true ]; then echo -e "  SSL         : ${WHITE}Let's Encrypt${NC}"
  elif [ "$PANEL_ASSUME_SSL"  == true ]; then echo -e "  SSL         : ${WHITE}Assume SSL (Cloudflare/proxy)${NC}"
  else                                        echo -e "  SSL         : ${WHITE}None (HTTP)${NC}"
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

panel_add_php_repo() {
  info "Adding PHP 8.3 repository..."
  case "$OS" in
    ubuntu)
      apt-get install -y software-properties-common >> "$LOG_FILE" 2>&1
      LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php >> "$LOG_FILE" 2>&1
      ;;
    debian)
      curl -fsSL https://packages.sury.org/php/apt.gpg \
        -o /etc/apt/trusted.gpg.d/php.gpg >> "$LOG_FILE" 2>&1
      echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" \
        > /etc/apt/sources.list.d/php.list
      ;;
  esac
  apt-get update -y >> "$LOG_FILE" 2>&1
  success "PHP 8.3 repository added"
}

panel_install_deps() {
  info "Installing PHP 8.3, MariaDB, NGINX, Redis"
  apt-get install -y \
    php8.3 php8.3-cli php8.3-common php8.3-gd \
    php8.3-mysql php8.3-mbstring php8.3-bcmath \
    php8.3-xml php8.3-fpm php8.3-curl php8.3-zip \
    mariadb-server mariadb-client \
    nginx redis-server \
    >> "$LOG_FILE" 2>&1
  success "Dependencies installed"
}

panel_enable_services() {
  info "Starting and enabling services..."
  systemctl enable --now mariadb      >> "$LOG_FILE" 2>&1
  systemctl enable --now redis-server >> "$LOG_FILE" 2>&1
  systemctl enable nginx              >> "$LOG_FILE" 2>&1
  # Make sure php-fpm is running
  systemctl enable --now php8.3-fpm  >> "$LOG_FILE" 2>&1
  success "Services started"
}

panel_firewall() {
  info "Configuring UFW firewall..."
  apt-get install -y ufw >> "$LOG_FILE" 2>&1
  ufw allow 22  >> "$LOG_FILE" 2>&1
  ufw allow 80  >> "$LOG_FILE" 2>&1
  ufw allow 443 >> "$LOG_FILE" 2>&1
  ufw --force enable >> "$LOG_FILE" 2>&1
  success "Firewall configured (ports 22, 80, 443)"
}

panel_install_composer() {
  info "Installing Composer"
  curl -fsSL https://getcomposer.org/installer -o /tmp/composer-setup.php >> "$LOG_FILE" 2>&1
  php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer >> "$LOG_FILE" 2>&1
  rm -f /tmp/composer-setup.php
  if ! /usr/local/bin/composer --version >> "$LOG_FILE" 2>&1; then
    error "Composer installation failed."
    exit 1
  fi
  success "Composer installed"
}

panel_setup_db() {
  info "Setting up MariaDB database and user..."
  mysql -u root << SQL >> "$LOG_FILE" 2>&1
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DB}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'127.0.0.1' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DB}\`.* TO '${MYSQL_USER}'@'127.0.0.1' WITH GRANT OPTION;
FLUSH PRIVILEGES;
SQL
  success "Database '${MYSQL_DB}' and user '${MYSQL_USER}' created"
}

panel_download() {
  info "Fetching latest Panel version from GitHub..."
  PANEL_VER=$(curl -fsSL https://api.github.com/repos/pterodactyl/panel/releases/latest \
    | grep '"tag_name"' | cut -d'"' -f4)

  if [[ -z "$PANEL_VER" ]]; then
    error "Could not fetch Panel version from GitHub API. Check internet connectivity."
    exit 1
  fi

  info "Downloading Pterodactyl Panel ${PANEL_VER}"
  mkdir -p /var/www/pterodactyl
  cd /var/www/pterodactyl

  curl -fsSL "https://github.com/pterodactyl/panel/releases/download/${PANEL_VER}/panel.tar.gz" \
    -o panel.tar.gz >> "$LOG_FILE" 2>&1
  tar -xzf panel.tar.gz >> "$LOG_FILE" 2>&1
  rm -f panel.tar.gz
  chmod -R 755 storage/* bootstrap/cache/
  cp .env.example .env
  success "Panel ${PANEL_VER} downloaded"
}

panel_composer_deps() {
  cd /var/www/pterodactyl
  info "Installing Composer dependencies (this can take 3-5 minutes)"
  # --no-progress prevents the animated progress bar which garbles the spinner
  # We show individual package lines via tee so the log has detail
  COMPOSER_ALLOW_SUPERUSER=1 /usr/local/bin/composer install \
    --no-dev \
    --optimize-autoloader \
    --no-interaction \
    --no-progress \
    >> "$LOG_FILE" 2>&1
  if [ ! -f /var/www/pterodactyl/vendor/autoload.php ]; then
    error "Composer failed — vendor/autoload.php missing. Check: $LOG_FILE"
    exit 1
  fi
  success "Composer dependencies installed"
}

panel_configure() {
  cd /var/www/pterodactyl

  local app_url="http://${PANEL_FQDN}"
  [ "$PANEL_ASSUME_SSL"  == true ] && app_url="https://${PANEL_FQDN}"
  [ "$PANEL_LETSENCRYPT" == true ] && app_url="https://${PANEL_FQDN}"

  info "Generating application key..."
  php artisan key:generate --force 2>&1 | tee -a "$LOG_FILE"

  info "Writing environment config..."
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
    2>&1 | tee -a "$LOG_FILE"

  info "Writing database config..."
  php artisan p:environment:database \
    --host="127.0.0.1" \
    --port="3306" \
    --database="${MYSQL_DB}" \
    --username="${MYSQL_USER}" \
    --password="${MYSQL_PASSWORD}" \
    --no-interaction \
    2>&1 | tee -a "$LOG_FILE"

  info "Running database migrations"
  php artisan migrate --seed --force >> "$LOG_FILE" 2>&1
  success "Migrations complete"

  info "Creating admin user..."
  php artisan p:user:make \
    --email="${ADMIN_EMAIL}" \
    --username="${ADMIN_USERNAME}" \
    --name-first="${ADMIN_FIRSTNAME}" \
    --name-last="${ADMIN_LASTNAME}" \
    --password="${ADMIN_PASSWORD}" \
    --admin=1 \
    --no-interaction \
    2>&1 | tee -a "$LOG_FILE"

  chown -R www-data:www-data /var/www/pterodactyl
  success "Panel configured and admin user created"
}

panel_cron() {
  info "Installing scheduler cron job..."
  # Remove any existing pterodactyl cron entry first to avoid duplicates
  (crontab -l 2>/dev/null | grep -v "pterodactyl/artisan schedule:run") | crontab - 2>/dev/null || true
  (crontab -l 2>/dev/null; echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1") | crontab -
  success "Cron job installed"
}

panel_queue_worker() {
  info "Installing pteroq queue worker service..."
  cat > /etc/systemd/system/pteroq.service << 'SERVICE'
[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service mariadb.service
Wants=redis-server.service mariadb.service

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
  systemctl daemon-reload           >> "$LOG_FILE" 2>&1
  systemctl enable --now pteroq     >> "$LOG_FILE" 2>&1
  success "pteroq service installed and started"
}

panel_nginx() {
  info "Configuring NGINX..."
  local PHP_SOCKET="/run/php/php8.3-fpm.sock"

  # Remove default site
  rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true

  if [ "$PANEL_ASSUME_SSL" == true ] || [ "$PANEL_LETSENCRYPT" == true ]; then
    # Assume SSL config — Cloudflare/reverse proxy terminates SSL,
    # so we still listen on 80 locally (Cloudflare sends HTTP to origin)
    cat > /etc/nginx/sites-available/pterodactyl.conf << NGINX
server {
    listen 80;
    server_name ${PANEL_FQDN};
    root /var/www/pterodactyl/public;
    index index.php;

    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Robots-Tag none;
    add_header Content-Security-Policy "frame-ancestors 'self'";
    add_header X-Frame-Options DENY;
    add_header Referrer-Policy same-origin;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

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
    # Plain HTTP config
    cat > /etc/nginx/sites-available/pterodactyl.conf << NGINX
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

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

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
         /etc/nginx/sites-enabled/pterodactyl.conf

  # Test config before restarting
  if ! nginx -t >> "$LOG_FILE" 2>&1; then
    error "NGINX config test failed. Check $LOG_FILE for details."
    exit 1
  fi
  systemctl restart nginx >> "$LOG_FILE" 2>&1
  success "NGINX configured"
}

panel_ssl() {
  info "Installing Certbot and obtaining Let's Encrypt certificate..."
  apt-get install -y certbot python3-certbot-nginx >> "$LOG_FILE" 2>&1

  local FAILED=false
  certbot --nginx --redirect --no-eff-email \
    --email "${ADMIN_EMAIL}" \
    -d "${PANEL_FQDN}" \
    --non-interactive >> "$LOG_FILE" 2>&1 || FAILED=true

  if [ "$FAILED" == true ] || [ ! -d "/etc/letsencrypt/live/${PANEL_FQDN}/" ]; then
    warn "Let's Encrypt failed — panel is accessible via HTTP only."
    warn "Make sure your domain points to this server and port 80 is open."
    PANEL_LETSENCRYPT=false
  else
    systemctl restart nginx >> "$LOG_FILE" 2>&1
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
  echo -e "  ${DIM}Ports used by Panel:${NC}"
  echo -e "  ${WHITE}:80 ${NC} — NGINX (HTTP / Cloudflare Tunnel origin)"
  echo -e "  ${WHITE}:443${NC} — NGINX HTTPS (if Let's Encrypt SSL)"
  echo -e "  ${WHITE}:3306${NC} — MariaDB (local only)"
  echo -e "  ${WHITE}:6379${NC} — Redis (local only)"
  echo -e ""
  echo -e "  ${DIM}Log: ${LOG_FILE}${NC}"
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e ""
}

install_panel() {
  collect_panel_inputs
  panel_add_php_repo
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
    validate_fqdn "$WINGS_FQDN" && break || error "Invalid domain or IP. Try again."
  done

  while true; do
    echo -n -e "  ${WHITE}Install MariaDB (for database host feature)? [y/N]:${NC} "
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
  echo -e "  ${WHITE}SSL Options:${NC}"
  echo -e "    ${WHITE}[1]${NC} Let's Encrypt (domain must point to this server)"
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
      validate_email "$WINGS_LE_EMAIL" && break || error "Invalid email."
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
  apt-get install -y ufw >> "$LOG_FILE" 2>&1
  ufw allow 22   >> "$LOG_FILE" 2>&1
  ufw allow 8080 >> "$LOG_FILE" 2>&1
  ufw allow 2022 >> "$LOG_FILE" 2>&1
  [ "$WINGS_LETSENCRYPT" == true ] && ufw allow 80 >> "$LOG_FILE" 2>&1
  [ "$WINGS_LETSENCRYPT" == true ] && ufw allow 443 >> "$LOG_FILE" 2>&1
  [ "$WINGS_INSTALL_DB"  == true ] && ufw allow 3306 >> "$LOG_FILE" 2>&1
  ufw --force enable >> "$LOG_FILE" 2>&1
  success "Firewall configured (22, 8080, 2022)"
}

wings_install_docker() {
  info "Installing Docker"
  apt-get remove -y docker docker-engine docker.io containerd runc >> "$LOG_FILE" 2>&1 || true
  mkdir -p /etc/apt/keyrings
  curl -fsSL "https://download.docker.com/linux/${OS}/gpg" \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg >> "$LOG_FILE" 2>&1
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/${OS} $(lsb_release -cs) stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -y >> "$LOG_FILE" 2>&1
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin \
    >> "$LOG_FILE" 2>&1
  systemctl enable --now docker >> "$LOG_FILE" 2>&1
  if ! docker info >> "$LOG_FILE" 2>&1; then
    error "Docker installed but failed to start."
    exit 1
  fi
  success "Docker installed and running"
}

wings_install_mariadb() {
  info "Installing MariaDB for database host feature..."
  apt-get install -y mariadb-server >> "$LOG_FILE" 2>&1
  systemctl enable --now mariadb >> "$LOG_FILE" 2>&1

  mysql -u root << SQL >> "$LOG_FILE" 2>&1
CREATE USER IF NOT EXISTS 'pterodactyluser'@'%' IDENTIFIED BY '${WINGS_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON *.* TO 'pterodactyluser'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
SQL

  # Allow remote connections
  sed -i 's/^bind-address\s*=.*/bind-address = 0.0.0.0/' \
    /etc/mysql/mariadb.conf.d/50-server.cnf 2>/dev/null || true
  systemctl restart mariadb >> "$LOG_FILE" 2>&1
  success "MariaDB installed, user 'pterodactyluser' created"
}

wings_download() {
  info "Downloading Pterodactyl Wings (latest)..."
  mkdir -p /etc/pterodactyl

  # Detect architecture with multiple fallback methods
  local raw_arch
  raw_arch="$(uname -m)"
  case "$raw_arch" in
    x86_64|amd64)           ARCH="amd64" ;;
    aarch64|arm64|armv8*)   ARCH="arm64" ;;
    *) error "Unsupported architecture: $raw_arch"; exit 1 ;;
  esac
  info "Detected architecture: $raw_arch → wings_linux_${ARCH}"

  # Fetch latest version — with fallback if GitHub API rate-limits
  WINGS_VER=$(curl -fsSL https://api.github.com/repos/pterodactyl/wings/releases/latest \
    | grep '"tag_name"' | cut -d'"' -f4)

  if [[ -z "$WINGS_VER" ]]; then
    warn "GitHub API failed — trying alternate version fetch..."
    WINGS_VER=$(curl -fsSL https://api.github.com/repos/pterodactyl/wings/releases \
      | grep '"tag_name"' | head -1 | cut -d'"' -f4)
  fi

  if [[ -z "$WINGS_VER" ]]; then
    error "Could not fetch Wings version. Check internet connectivity."
    exit 1
  fi
  info "Latest Wings version: $WINGS_VER"

  local WINGS_URL="https://github.com/pterodactyl/wings/releases/download/${WINGS_VER}/wings_linux_${ARCH}"
  info "Download URL: $WINGS_URL"

  info "Downloading Wings ${WINGS_VER} (${ARCH})"
  # Download to a temp file first so we can check it before installing
  curl -fsSL "$WINGS_URL" -o /tmp/wings_download >> "$LOG_FILE" 2>&1

  # Check the downloaded file is actually an ELF binary, not an HTML error page
  local file_type
  file_type="$(file /tmp/wings_download 2>/dev/null || true)"
  info "Downloaded file type: $file_type" >> "$LOG_FILE" 2>&1 || true
  echo "Downloaded file type: $file_type" >> "$LOG_FILE"

  if echo "$file_type" | grep -qiE "HTML|ASCII text|empty"; then
    error "Downloaded file is not a binary (got HTML/text — likely a 404 or GitHub error)."
    error "URL tried: $WINGS_URL"
    error "Run: curl -I \"$WINGS_URL\" to check manually."
    rm -f /tmp/wings_download
    exit 1
  fi

  mv /tmp/wings_download /usr/local/bin/wings
  chmod +x /usr/local/bin/wings

  # Test execution - FIXED: Use 'version' subcommand instead of '--version' flag
  if ! /usr/local/bin/wings version >> "$LOG_FILE" 2>&1; then
    # Get the actual error message for diagnosis
    local exec_err
    exec_err=$(/usr/local/bin/wings version 2>&1 || true)
    error "Wings binary failed to execute: $exec_err"
    error "Architecture mismatch or missing shared libraries."
    error "Your machine reports: $raw_arch"
    exit 1
  fi

  success "Wings ${WINGS_VER} (${ARCH}) downloaded and verified"
}

wings_service() {
  info "Installing Wings systemd service..."
  cat > /etc/systemd/system/wings.service << 'SERVICE'
[Unit]
Description=Pterodactyl Wings
After=docker.service network-online.target
Requires=docker.service
Wants=network-online.target

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
  systemctl daemon-reload        >> "$LOG_FILE" 2>&1
  systemctl enable wings         >> "$LOG_FILE" 2>&1
  success "Wings service installed (will start after config.yml is placed)"
}

wings_ssl() {
  info "Obtaining Let's Encrypt certificate for ${WINGS_FQDN}..."
  apt-get install -y certbot >> "$LOG_FILE" 2>&1

  local FAILED=false
  certbot certonly --standalone --no-eff-email \
    --email "${WINGS_LE_EMAIL}" \
    -d "${WINGS_FQDN}" \
    --non-interactive >> "$LOG_FILE" 2>&1 || FAILED=true

  if [ "$FAILED" == true ] || [ ! -d "/etc/letsencrypt/live/${WINGS_FQDN}/" ]; then
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
  echo -e "  ${DIM}Ports used by Wings:${NC}"
  echo -e "  ${WHITE}:8080${NC} — Wings API (Panel → Node communication)"
  echo -e "  ${WHITE}:2022${NC} — SFTP (file uploads/downloads)"
  [ "$WINGS_LETSENCRYPT" == true ] && echo -e "  ${WHITE}:443 ${NC} — HTTPS Wings API (SSL)"
  [ "$WINGS_INSTALL_DB"  == true ] && echo -e "  ${WHITE}:3306${NC} — MariaDB (database host)"
  echo -e ""
  echo -e "  ${BOLD}${RED}★★★ IMPORTANT NEXT STEPS FOR WINGS! ★★★${NC}"
  echo -e "  1. Go to your Panel → ${WHITE}Admin → Nodes → Create Node${NC}"
  echo -e "  2. Fill in node details (using your public Wings domain, e.g., wings.yourdomain.com)"
  echo -e "  3. Open the ${WHITE}Configuration${NC} tab and ${CYAN}${BOLD}COPY THE ENTIRE YAML BLOCK${NC}"
  echo -e "  4. On this server, create the Wings config file:"
  echo -e "     ${CYAN}nano /etc/pterodactyl/config.yml${NC}"
  echo -e "  5. ${CYAN}${BOLD}PASTE THE COPIED YAML INTO THE FILE and SAVE IT.${NC}"
  echo -e "  6. Then, start Wings: ${CYAN}systemctl start wings${NC}"
  echo -e "  7. Verify its status: ${CYAN}systemctl status wings${NC}"
  echo -e "     If it's still failing, check logs: ${CYAN}journalctl -u wings -n 50 --no-pager${NC}"
  echo -e ""
  if [ "$WINGS_INSTALL_DB" == true ]; then
    echo -e "  ${BOLD}DB Host User :${NC} ${WHITE}pterodactyluser${NC}"
    echo -e "  ${BOLD}DB Host Pass :${NC} ${WHITE}${WINGS_DB_PASSWORD}${NC}"
    echo -e ""
  fi
  echo -e "  ${DIM}Log: ${LOG_FILE}${NC}"
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e ""
}

install_wings() {
  collect_wings_inputs
  apt-get update -y >> "$LOG_FILE" 2>&1
  [ "$WINGS_FIREWALL"   == true ] && wings_firewall
  wings_install_docker
  [ "$WINGS_INSTALL_DB" == true ] && wings_install_mariadb
  wings_download
  wings_service
  [ "$WINGS_LETSENCRYPT" == true ] && wings_ssl
  wings_print_done
}

###############################################################################
# UNINSTALL
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
    </dev/fd/63: line 649: unexpected EOF while looking for matching `"'`
/dev/fd/63: line 650: syntax error: unexpected end of file
