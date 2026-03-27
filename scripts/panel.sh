#!/bin/bash

set -e

######################################################################################
#                                                                                    #
#  Pterodactyl Installer by XENTO — Panel Script                                    #
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
GITHUB_URL="https://raw.githubusercontent.com/thexento/Pterodactyl-Installer/main"

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
output()  { echo -e "        $*"; }

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
    error "Cannot detect OS. Supported: Ubuntu 20/22/24, Debian 11/12."
    exit 1
  fi

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
    rocky|almalinux)
      case "$OS_VER_MAJOR" in
        8|9) ;;
        *) error "Unsupported $OS version: $OS_VER"; exit 1 ;;
      esac
      ;;
    *)
      error "Unsupported OS: $OS"
      exit 1
      ;;
  esac

  success "Detected OS: $OS $OS_VER"
}

# ──────────────────────────────────────────────
#  Validation helpers
# ──────────────────────────────────────────────
validate_email() {
  [[ "$1" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]
}

validate_fqdn() {
  [[ "$1" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]] || \
  [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

# ──────────────────────────────────────────────
#  Collect all inputs BEFORE installing anything
# ──────────────────────────────────────────────
collect_inputs() {
  echo -e ""
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  ${BOLD}Panel Configuration${NC}"
  echo -e "  ${DIM}All questions are asked before installation begins.${NC}"
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e ""

  # FQDN
  while true; do
    echo -n -e "  ${WHITE}Panel domain or IP (e.g. panel.example.com):${NC} "
    read -r FQDN
    if validate_fqdn "$FQDN"; then break
    else error "Invalid domain or IP address. Try again."; fi
  done

  # Admin email
  while true; do
    echo -n -e "  ${WHITE}Admin email address:${NC} "
    read -r ADMIN_EMAIL
    if validate_email "$ADMIN_EMAIL"; then break
    else error "Invalid email address. Try again."; fi
  done

  # Admin username
  while true; do
    echo -n -e "  ${WHITE}Admin username (min 3 chars):${NC} "
    read -r ADMIN_USERNAME
    [[ -n "$ADMIN_USERNAME" && ${#ADMIN_USERNAME} -ge 3 ]] && break
    error "Username must be at least 3 characters."
  done

  # Admin first name
  while true; do
    echo -n -e "  ${WHITE}Admin first name:${NC} "
    read -r ADMIN_FIRSTNAME
    [[ -n "$ADMIN_FIRSTNAME" ]] && break
    error "First name cannot be empty."
  done

  # Admin last name
  while true; do
    echo -n -e "  ${WHITE}Admin last name:${NC} "
    read -r ADMIN_LASTNAME
    [[ -n "$ADMIN_LASTNAME" ]] && break
    error "Last name cannot be empty."
  done

  # Admin password
  while true; do
    echo -n -e "  ${WHITE}Admin password (min 8 chars):${NC} "
    read -rs ADMIN_PASSWORD
    echo ""
    [[ ${#ADMIN_PASSWORD} -ge 8 ]] && break
    error "Password must be at least 8 characters."
  done

  # Timezone
  echo -n -e "  ${WHITE}Timezone (default: UTC):${NC} "
  read -r TIMEZONE
  TIMEZONE="${TIMEZONE:-UTC}"

  # SSL option
  echo -e ""
  echo -e "  ${WHITE}SSL Options:${NC}"
  echo -e "    ${WHITE}[1]${NC} Use Let's Encrypt (auto SSL — requires a valid domain)"
  echo -e "    ${WHITE}[2]${NC} Assume SSL already configured (custom cert / reverse proxy)"
  echo -e "    ${WHITE}[3]${NC} No SSL (HTTP only)"
  while true; do
    echo -n -e "  ${WHITE}SSL choice [1-3]:${NC} "
    read -r SSL_CHOICE
    case "$SSL_CHOICE" in
      1) CONFIGURE_LETSENCRYPT=true;  ASSUME_SSL=false; break ;;
      2) CONFIGURE_LETSENCRYPT=false; ASSUME_SSL=true;  break ;;
      3) CONFIGURE_LETSENCRYPT=false; ASSUME_SSL=false; break ;;
      *) error "Enter 1, 2, or 3." ;;
    esac
  done

  # Firewall
  echo -e ""
  while true; do
    echo -n -e "  ${WHITE}Configure UFW firewall automatically? [y/N]:${NC} "
    read -r FIREWALL_INPUT
    case "$FIREWALL_INPUT" in
      [Yy]*) CONFIGURE_FIREWALL=true;  break ;;
      [Nn]*|"") CONFIGURE_FIREWALL=false; break ;;
      *) error "Enter y or n." ;;
    esac
  done

  # Derived values
  MYSQL_DB="panel"
  MYSQL_USER="pterodactyl"
  MYSQL_PASSWORD="$(tr -dc 'A-Za-z0-9!@#%^&*' </dev/urandom | head -c 32)"

  # Summary
  echo -e ""
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  ${BOLD}Installation Summary${NC}"
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  Panel FQDN  : ${WHITE}${FQDN}${NC}"
  echo -e "  Admin Email : ${WHITE}${ADMIN_EMAIL}${NC}"
  echo -e "  Username    : ${WHITE}${ADMIN_USERNAME}${NC}"
  echo -e "  Full Name   : ${WHITE}${ADMIN_FIRSTNAME} ${ADMIN_LASTNAME}${NC}"
  echo -e "  Timezone    : ${WHITE}${TIMEZONE}${NC}"
  echo -e "  SSL         : ${WHITE}$([ "$CONFIGURE_LETSENCRYPT" == true ] && echo "Let's Encrypt" || { [ "$ASSUME_SSL" == true ] && echo "Assume SSL"; } || echo "None (HTTP)")${NC}"
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
#  Installation steps
# ──────────────────────────────────────────────
install_firewall() {
  info "Configuring UFW firewall..."
  install_packages "ufw"
  ufw allow 22  &>>"$LOG_FILE"
  ufw allow 80  &>>"$LOG_FILE"
  ufw allow 443 &>>"$LOG_FILE"
  ufw --force enable &>>"$LOG_FILE"
  success "Firewall configured (ports 22, 80, 443 open)"
}

add_repos() {
  info "Adding package repositories..."
  case "$OS" in
    ubuntu)
      install_packages "software-properties-common apt-transport-https ca-certificates gnupg"
      add-apt-repository universe -y &>>"$LOG_FILE"
      LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php &>>"$LOG_FILE"
      ;;
    debian)
      install_packages "dirmngr ca-certificates apt-transport-https lsb-release"
      curl -fsSL https://packages.sury.org/php/apt.gpg \
        -o /etc/apt/trusted.gpg.d/php.gpg &>>"$LOG_FILE"
      echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" \
        | tee /etc/apt/sources.list.d/php.list &>>"$LOG_FILE"
      ;;
    rocky|almalinux)
      install_packages "epel-release" || true
      install_packages "http://rpms.remirepo.net/enterprise/remi-release-${OS_VER_MAJOR}.rpm" || true
      dnf module enable -y php:remi-8.3 &>>"$LOG_FILE"
      ;;
  esac
  success "Repositories added"
}

install_dependencies() {
  info "Installing system dependencies..."

  update_repos

  [ "$CONFIGURE_FIREWALL" == true ] && install_firewall

  case "$OS" in
    ubuntu|debian)
      install_packages \
        "php8.3 php8.3-cli php8.3-common php8.3-gd php8.3-mysql php8.3-mbstring \
         php8.3-bcmath php8.3-xml php8.3-fpm php8.3-curl php8.3-zip \
         mariadb-common mariadb-server mariadb-client \
         nginx redis-server \
         zip unzip tar git cron curl wget"
      [ "$CONFIGURE_LETSENCRYPT" == true ] && \
        install_packages "certbot python3-certbot-nginx"
      ;;
    rocky|almalinux)
      install_packages \
        "php php-common php-fpm php-cli php-mysqlnd php-gd php-mbstring \
         php-pdo php-zip php-bcmath php-dom php-opcache php-posix \
         mariadb mariadb-server \
         nginx redis \
         zip unzip tar git cronie curl wget"
      [ "$CONFIGURE_LETSENCRYPT" == true ] && \
        install_packages "certbot python3-certbot-nginx"
      ;;
  esac

  success "Dependencies installed"
}

enable_services() {
  info "Enabling and starting services..."
  case "$OS" in
    ubuntu|debian)
      systemctl enable redis-server &>>"$LOG_FILE"
      systemctl start  redis-server &>>"$LOG_FILE"
      ;;
    rocky|almalinux)
      systemctl enable redis &>>"$LOG_FILE"
      systemctl start  redis &>>"$LOG_FILE"
      ;;
  esac
  systemctl enable nginx   &>>"$LOG_FILE"
  systemctl enable mariadb &>>"$LOG_FILE"
  systemctl start  mariadb &>>"$LOG_FILE"
  success "Services enabled"
}

install_composer() {
  info "Installing Composer..."
  curl -sS https://getcomposer.org/installer \
    | php -- --install-dir=/usr/local/bin --filename=composer &>>"$LOG_FILE"
  success "Composer installed"
}

setup_database() {
  info "Setting up MariaDB database and user..."
  mysql -u root &>>"$LOG_FILE" <<SQL
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DB}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'127.0.0.1' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DB}\`.* TO '${MYSQL_USER}'@'127.0.0.1' WITH GRANT OPTION;
FLUSH PRIVILEGES;
SQL
  success "Database '${MYSQL_DB}' and user '${MYSQL_USER}' created"
}

download_panel() {
  info "Downloading Pterodactyl Panel (latest release)..."
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

install_composer_deps() {
  info "Installing Composer dependencies..."
  cd /var/www/pterodactyl
  [ "$OS" == "rocky" ] || [ "$OS" == "almalinux" ] && export PATH=/usr/local/bin:$PATH
  COMPOSER_ALLOW_SUPERUSER=1 composer install \
    --no-dev --optimize-autoloader --no-interaction &>>"$LOG_FILE"
  success "Composer dependencies installed"
}

configure_panel() {
  info "Configuring Panel environment..."
  cd /var/www/pterodactyl

  local app_url="http://${FQDN}"
  [ "$ASSUME_SSL" == true ] && app_url="https://${FQDN}"
  [ "$CONFIGURE_LETSENCRYPT" == true ] && app_url="https://${FQDN}"

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

  success "Panel configured, admin user created"
}

set_permissions() {
  info "Setting file permissions..."
  case "$OS" in
    ubuntu|debian)
      chown -R www-data:www-data /var/www/pterodactyl/* &>>"$LOG_FILE"
      ;;
    rocky|almalinux)
      chown -R nginx:nginx /var/www/pterodactyl/* &>>"$LOG_FILE"
      ;;
  esac
  success "Permissions set"
}

setup_cron() {
  info "Installing cron job..."
  (crontab -l 2>/dev/null; \
    echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1") \
    | crontab -
  success "Cron job installed"
}

install_pteroq() {
  info "Installing pteroq queue worker service..."

  local pteroq_user="www-data"
  [ "$OS" == "rocky" ] || [ "$OS" == "almalinux" ] && pteroq_user="nginx"

  cat > /etc/systemd/system/pteroq.service <<SERVICE
[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service

[Service]
User=${pteroq_user}
Group=${pteroq_user}
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
SERVICE

  systemctl daemon-reload       &>>"$LOG_FILE"
  systemctl enable pteroq       &>>"$LOG_FILE"
  systemctl start  pteroq       &>>"$LOG_FILE"
  success "pteroq service installed and started"
}

configure_nginx() {
  info "Configuring NGINX..."

  local php_socket="/run/php/php8.3-fpm.sock"
  [ "$OS" == "rocky" ] || [ "$OS" == "almalinux" ] && \
    php_socket="/var/run/php-fpm/pterodactyl.sock"

  local config_avail="/etc/nginx/sites-available"
  local config_enabl="/etc/nginx/sites-enabled"
  if [ "$OS" == "rocky" ] || [ "$OS" == "almalinux" ]; then
    config_avail="/etc/nginx/conf.d"
    config_enabl="/etc/nginx/conf.d"
  fi

  rm -f "${config_enabl}/default" 2>/dev/null || true

  if [ "$ASSUME_SSL" == true ]; then
    # Assume SSL (custom cert already in place)
    cat > "${config_avail}/pterodactyl.conf" <<NGINX
server {
    listen 80;
    server_name ${FQDN};
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ${FQDN};

    root /var/www/pterodactyl/public;
    index index.php;

    ssl_certificate /etc/letsencrypt/live/${FQDN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${FQDN}/privkey.pem;
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

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:${php_socket};
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
    # HTTP only
    cat > "${config_avail}/pterodactyl.conf" <<NGINX
server {
    listen 80;
    server_name ${FQDN};

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
        fastcgi_pass unix:${php_socket};
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

  # Symlink for ubuntu/debian
  if [ "$OS" == "ubuntu" ] || [ "$OS" == "debian" ]; then
    ln -sf "${config_avail}/pterodactyl.conf" \
           "${config_enabl}/pterodactyl.conf" 2>/dev/null || true
  fi

  if [ "$CONFIGURE_LETSENCRYPT" == false ]; then
    nginx -t &>>"$LOG_FILE"
    systemctl restart nginx &>>"$LOG_FILE"
  fi

  success "NGINX configured"
}

obtain_ssl() {
  info "Obtaining Let's Encrypt certificate for ${FQDN}..."
  FAILED=false

  certbot --nginx --redirect --no-eff-email \
    --email "${ADMIN_EMAIL}" \
    -d "${FQDN}" \
    --non-interactive || FAILED=true

  if [ ! -d "/etc/letsencrypt/live/${FQDN}/" ] || [ "$FAILED" == true ]; then
    warn "Let's Encrypt failed. Falling back to HTTP."
    CONFIGURE_LETSENCRYPT=false
    ASSUME_SSL=false
    configure_nginx
  else
    systemctl restart nginx &>>"$LOG_FILE"
    success "SSL certificate obtained"
  fi
}

selinux_allow() {
  if [ "$OS" == "rocky" ] || [ "$OS" == "almalinux" ]; then
    setsebool -P httpd_can_network_connect 1 &>>"$LOG_FILE" || true
    setsebool -P httpd_execmem 1            &>>"$LOG_FILE" || true
    setsebool -P httpd_unified 1            &>>"$LOG_FILE" || true
  fi
}

php_fpm_rocky() {
  if [ "$OS" == "rocky" ] || [ "$OS" == "almalinux" ]; then
    curl -fsSL -o /etc/php-fpm.d/www-pterodactyl.conf \
      "${GITHUB_URL}/configs/www-pterodactyl.conf" &>>"$LOG_FILE" || \
    cat > /etc/php-fpm.d/www-pterodactyl.conf <<FPMCONF
[pterodactyl]
user = nginx
group = nginx
listen = /var/run/php-fpm/pterodactyl.sock
listen.owner = nginx
listen.group = nginx
listen.mode = 0750
pm = ondemand
pm.max_children = 9
pm.process_idle_timeout = 10s
pm.max_requests = 200
FPMCONF
    systemctl enable php-fpm &>>"$LOG_FILE"
    systemctl start  php-fpm &>>"$LOG_FILE"
  fi
}

print_completion() {
  local proto="http"
  [ "$CONFIGURE_LETSENCRYPT" == true ] && proto="https"
  [ "$ASSUME_SSL" == true ]            && proto="https"

  echo -e ""
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  ${GREEN}${BOLD}✓ Panel Installation Complete!${NC}"
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e ""
  echo -e "  ${BOLD}Panel URL    :${NC} ${CYAN}${proto}://${FQDN}${NC}"
  echo -e "  ${BOLD}Username     :${NC} ${WHITE}${ADMIN_USERNAME}${NC}"
  echo -e "  ${BOLD}Email        :${NC} ${WHITE}${ADMIN_EMAIL}${NC}"
  echo -e "  ${BOLD}DB Password  :${NC} ${WHITE}${MYSQL_PASSWORD}${NC}"
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
  add_repos
  install_dependencies
  enable_services
  install_composer
  setup_database
  download_panel
  install_composer_deps
  configure_panel
  set_permissions
  setup_cron
  install_pteroq
  [ "$OS" == "rocky" ] || [ "$OS" == "almalinux" ] && selinux_allow && php_fpm_rocky
  configure_nginx
  [ "$CONFIGURE_LETSENCRYPT" == true ] && obtain_ssl

  print_completion
}

main "$@"