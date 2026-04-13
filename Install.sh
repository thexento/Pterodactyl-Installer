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
BASE_URL="https://raw.githubusercontent.com/thexento/Pterodactyl-Installer/main"
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
error()   { echo -e "${RED}[ERR ]${NC}  $*" >&2; }

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

require_root() {
  if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root."
    error "Try: sudo bash install.sh"
    exit 1
  fi
}

check_curl() {
  if ! command -v curl &>/dev/null; then
    echo "curl is required. Installing..."
    apt-get update -y && apt-get install -y curl || { error "Failed to install curl."; exit 1; }
  fi
}

run_script() {
  local script="$1"
  info "Fetching ${script} script..."
  bash <(curl -fsSL "${BASE_URL}/scripts/${script}.sh") |& tee -a "$LOG_FILE"
}

main() {
  print_header
  require_root
  check_curl

  touch "$LOG_FILE"
  echo "=== Pterodactyl Installer by XENTO — $(date) ===" >> "$LOG_FILE"

  echo -e "  ${BOLD}What would you like to do?${NC}\n"
  echo -e "  ${WHITE}[1]${NC} Install Panel"
  echo -e "  ${WHITE}[2]${NC} Install Wings"
  echo -e "  ${WHITE}[3]${NC} Install Panel + Wings (same machine)"
  echo -e "  ${WHITE}[4]${NC} Install phpMyAdmin"
  echo -e "  ${WHITE}[5]${NC} Uninstall Panel / Wings"
  echo -e ""
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e ""

  local choice
  while true; do
    echo -n -e "  ${WHITE}Choice [1-5]:${NC} "
    read -r choice
    case "$choice" in
      1|2|3|4|5) break ;;
      *) error "Invalid option. Enter 1–5." ;;
    esac
  done

  echo "" >> "$LOG_FILE"

  case "$choice" in
    1)
      info "Starting Panel installation..."
      run_script "panel"
      ;;
    2)
      info "Starting Wings installation..."
      run_script "wings"
      ;;
    3)
      info "Starting Panel + Wings installation..."
      run_script "panel"
      echo ""
      echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
      info "Panel complete. Now installing Wings..."
      echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
      echo ""
      run_script "wings"
      ;;
    4)
      info "Starting phpMyAdmin installation..."
      run_script "phpmyadmin"
      ;;
    5)
      info "Starting uninstaller..."
      run_script "uninstall"
      ;;
  esac
}

main "$@"