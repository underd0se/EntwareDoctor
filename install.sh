#!/bin/sh
# =========================================================================================================================
# EntwareDoctor Universal Installer for Asuswrt-Merlin
#
# Licensed under GNU General Public License v3.0 (GPLv3)
# =========================================================================================================================

set -e

export PATH="/opt/bin:/opt/sbin:/usr/bin:/usr/sbin:/bin:/sbin:${PATH:-}"

REPO_RAW_URL="https://raw.githubusercontent.com/underd0se/EntwareDoctor/main"
VERSION="v1.0.1"
INSTALL_DIR="/jffs/scripts"
TARGET_SCRIPT="${INSTALL_DIR}/entware-doctor"

# Colors
if [ -t 1 ]; then
    C_RESET="\033[0m"
    C_BOLD="\033[1m"
    C_GREEN="\033[1;32m"
    C_CYAN="\033[1;36m"
    C_YELLOW="\033[1;33m"
    C_RED="\033[1;31m"
else
    C_RESET=""
    C_BOLD=""
    C_GREEN=""
    C_CYAN=""
    C_YELLOW=""
    C_RED=""
fi

printf "\n%b" "${C_GREEN}"
cat <<'EOF'
    ______      __                            ____             __             
   / ____/___  / /__      ______ _________   / __ \____  _____/ /_____  _____
  / __/ / __ \/ __/ | /| / / __ `/ ___/ _ \ / / / / __ \/ ___/ __/ __ \/ ___/
 / /___/ / / / /_ | |/ |/ / /_/ / /  /  __// /_/ / /_/ / /__/ /_/ /_/ / /    
/_____/_/ /_/\__/ |__/|__/\__,_/_/   \___//_____/\____/\___/\__/\____/_/     
                                  Universal Installer
EOF
printf "%b\n\n" "${C_RESET}"

# -------------------------------------------------------------------------------------------------------------------------
# Step 1: Pre-Flight Environment Checks

printf "%b[*] Checking router environment...%b\n" "${C_CYAN}" "${C_RESET}"

if [ ! -d "/jffs/scripts" ]; then
    printf "%b[!] Error: /jffs/scripts not found. Please enable JFFS custom scripts in Asuswrt-Merlin Administration settings.%b\n" "${C_RED}" "${C_RESET}"
    exit 1
fi

if [ ! -d "/opt" ]; then
    printf "%b[!] Warning: /opt not found. Entware may not be initialized yet.%b\n" "${C_YELLOW}" "${C_RESET}"
fi

# -------------------------------------------------------------------------------------------------------------------------
# Step 2: Download Script

DOWNLOAD_URL="${REPO_RAW_URL}/entware-doctor.sh?nocache=$(date +%s)"
TMP_FILE="/tmp/entware-doctor.tmp"

printf "%b[*] Downloading EntwareDoctor (%s)...%b\n" "${C_CYAN}" "${VERSION}" "${C_RESET}"

if which curl >/dev/null 2>&1; then
    curl -fsSL "${DOWNLOAD_URL}" -o "${TMP_FILE}"
elif [ -x /usr/sbin/curl ]; then
    /usr/sbin/curl -fsSL "${DOWNLOAD_URL}" -o "${TMP_FILE}"
elif which wget >/dev/null 2>&1; then
    wget -q "${DOWNLOAD_URL}" -O "${TMP_FILE}"
elif [ -x /usr/sbin/wget ]; then
    /usr/sbin/wget -q "${DOWNLOAD_URL}" -O "${TMP_FILE}"
else
    printf "%b[!] Error: Neither curl nor wget found on system.%b\n" "${C_RED}" "${C_RESET}"
    exit 1
fi

if [ ! -s "${TMP_FILE}" ]; then
    printf "%b[!] Error: Download failed or file is empty.%b\n" "${C_RED}" "${C_RESET}"
    rm -f "${TMP_FILE}"
    exit 1
fi

# -------------------------------------------------------------------------------------------------------------------------
# Step 3: Install Script & Symlink

printf "%b[*] Installing to %s...%b\n" "${C_CYAN}" "${TARGET_SCRIPT}" "${C_RESET}"

chmod 755 "${TMP_FILE}"
mv -f "${TMP_FILE}" "${TARGET_SCRIPT}"

if [ -d "/opt/bin" ]; then
    ln -sf "${TARGET_SCRIPT}" "/opt/bin/entware-doctor"
fi

# -------------------------------------------------------------------------------------------------------------------------
# Step 4: Installation Complete

printf "\n%b===================================================================%b\n" "${C_GREEN}" "${C_RESET}"
printf "%b  EntwareDoctor %s installed successfully!%b\n" "${C_GREEN}" "${VERSION}" "${C_RESET}"
printf "%b===================================================================%b\n\n" "${C_GREEN}" "${C_RESET}"
printf "To run your first diagnostic scan:\n\n"
printf "  %bentware-doctor%b\n\n" "${C_BOLD}" "${C_RESET}"
printf "To run an automated repair & orphan cleanup:\n\n"
printf "  %bentware-doctor --fix%b\n\n" "${C_BOLD}" "${C_RESET}"
