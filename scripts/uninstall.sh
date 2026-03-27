#!/bin/bash

set -e

######################################################################################
#                                                                                    #
#  Pterodactyl Installer by XENTO — Uninstaller Script                              #
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
  else
    OS="unknown"
  fi
}

# ──────────────────────────────────────────────
#  Collect inputs
# ──────────────────────────────────────────────
collect_inputs() {
  echo -e ""
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  ${BOLD}${RED}Uninstaller${NC}"
  echo -e "  ${DIM}This will permanently remove selected components.${NC}"
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e ""

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
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  ${BOLD}${RED}⚠  This action is IRREVERSIBLE.${NC}"
  echo -e "  Remove Panel : ${WHITE}$([ "$RM_PANEL" == true ] && echo "YES" || echo "No")${NC}"
  echo -e "  Remove Wings : ${WHITE}$([ "$RM_WINGS" == true ] && echo "YES" || echo "No")${NC}"
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e ""

  while true; do
    echo -n -e "  ${RED}Type 'yes' to confirm uninstall:${NC} "
    read -r CONFIRM
    case "$CONFIRM" in
      yes) break ;;
      *) error "Type exactly 'yes' to confirm, or Ctrl+C to cancel." ;;
    esac
  done
  echo -e ""
}

# ──────────────────────────────────────────────
#  Uninstall functions
# ──────────────────────────────────────────────
rm_panel_files() {
  info "Removing Panel files..."
  rm -rf /var/www/pterodactyl /usr/local/bin/composer

  case "$OS" in
    ubuntu|debian)
      [ -L /etc/nginx/sites-enabled/pterodactyl.conf ] && \
        unlink /etc/nginx/sites-enabled/pterodactyl.conf || true
      [ -f /etc/nginx/sites-available/pterodactyl.conf ] && \
        rm -f /etc/nginx/sites-available/pterodactyl.conf || true
      [ ! -L /etc/nginx/sites-enabled/default ] && \
        [ -f /etc/nginx/sites-available/default ] && \
        ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default 2>/dev/null || true
      ;;
    rocky|almalinux)
      [ -f /etc/nginx/conf.d/pterodactyl.conf ] && \
        rm -f /etc/nginx/conf.d/pterodactyl.conf || true
      ;;
  esac

  systemctl restart nginx 2>/dev/null || true
  success "Panel files removed"
}

rm_services() {
  info "Removing Panel services..."
  systemctl disable --now pteroq 2>/dev/null || true
  rm -f /etc/systemd/system/pteroq.service

  case "$OS" in
    ubuntu|debian)
      systemctl disable --now redis-server 2>/dev/null || true
      ;;
    rocky|almalinux)
      systemctl disable --now redis     2>/dev/null || true
      systemctl disable --now php-fpm   2>/dev/null || true
      rm -f /etc/php-fpm.d/www-pterodactyl.conf
      ;;
  esac

  systemctl daemon-reload
  success "Panel services removed"
}

rm_cron() {
  info "Removing cron jobs..."
  crontab -l 2>/dev/null \
    | grep -vF "php /var/www/pterodactyl/artisan schedule:run" \
    | crontab - || true
  success "Cron jobs removed"
}

rm_database() {
  info "Removing Pterodactyl database..."

  # Try to detect database name
  local valid_db
  valid_db=$(mysql -u root -e \
    "SELECT schema_name FROM information_schema.schemata;" 2>/dev/null \
    | grep -v -E 'schema_name|information_schema|performance_schema|mysql|sys' || true)

  if [[ -z "$valid_db" ]]; then
    warn "No removable databases found. Skipping."
    return
  fi

  local DATABASE=""
  if echo "$valid_db" | grep -q "^panel$"; then
    echo -n -e "  ${WHITE}Database 'panel' detected — remove it? [y/N]:${NC} "
    read -r IS_PANEL
    [[ "$IS_PANEL" =~ [Yy] ]] && DATABASE="panel"
  fi

  if [[ -z "$DATABASE" ]]; then
    echo -e "  Available databases: ${WHITE}${valid_db}${NC}"
    echo -n -e "  ${WHITE}Enter database name to remove (or leave blank to skip):${NC} "
    read -r DATABASE
  fi

  if [[ -n "$DATABASE" ]]; then
    mysql -u root -e "DROP DATABASE IF EXISTS \`${DATABASE}\`;" 2>>"$LOG_FILE" || \
      warn "Failed to drop database ${DATABASE}"
    success "Database '${DATABASE}' removed"
  else
    info "Skipping database removal"
  fi

  # Remove DB user
  local valid_users
  valid_users=$(mysql -u root -e "SELECT user FROM mysql.user;" 2>/dev/null \
    | grep -v -E '^(user|root|mysql|mariadb\.sys)$' || true)

  if [[ -z "$valid_users" ]]; then
    warn "No removable database users found. Skipping."
    return
  fi

  local DB_USER=""
  if echo "$valid_users" | grep -q "^pterodactyl$"; then
    echo -n -e "  ${WHITE}User 'pterodactyl' detected — remove it? [y/N]:${NC} "
    read -r IS_USER
    [[ "$IS_USER" =~ [Yy] ]] && DB_USER="pterodactyl"
  fi

  if [[ -z "$DB_USER" ]]; then
    echo -n -e "  ${WHITE}Enter DB username to remove (or leave blank to skip):${NC} "
    read -r DB_USER
  fi

  if [[ -n "$DB_USER" ]]; then
    mysql -u root -e "DROP USER IF EXISTS '${DB_USER}'@'127.0.0.1';" 2>>"$LOG_FILE" || \
      warn "Failed to drop user ${DB_USER}"
    mysql -u root -e "FLUSH PRIVILEGES;" 2>>"$LOG_FILE" || true
    success "User '${DB_USER}' removed"
  else
    info "Skipping user removal"
  fi
}

rm_docker_containers() {
  info "Removing Docker containers and images..."
  if command -v docker &>/dev/null; then
    docker system prune -a -f &>>"$LOG_FILE" || true
  fi
  success "Docker containers and images removed"
}

rm_wings_files() {
  info "Removing Wings files..."
  systemctl disable --now wings 2>/dev/null || true
  rm -f /etc/systemd/system/wings.service
  rm -rf /etc/pterodactyl
  rm -f /usr/local/bin/wings
  rm -rf /var/lib/pterodactyl
  systemctl daemon-reload
  success "Wings files removed"
}

print_completion() {
  echo -e ""
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  ${GREEN}${BOLD}✓ Uninstall Complete${NC}"
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e ""
  echo -e "  ${DIM}Note: PHP, NGINX, MariaDB, Redis, and Docker were not removed.${NC}"
  echo -e "  ${DIM}Remove them manually if no longer needed.${NC}"
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

  [ "$RM_PANEL" == true ] && rm_panel_files
  [ "$RM_PANEL" == true ] && rm_cron
  [ "$RM_PANEL" == true ] && rm_database
  [ "$RM_PANEL" == true ] && rm_services
  [ "$RM_WINGS" == true ] && rm_docker_containers
  [ "$RM_WINGS" == true ] && rm_wings_files

  print_completion
}

main "$@"