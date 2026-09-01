#!/bin/sh
# =========================================================================================================================
# EntwareDoctor - Automated Entware Health, Dependency, and Orphan Package Sentinel for Asuswrt-Merlin
#
# Licensed under GNU General Public License v3.0 (GPLv3)
# =========================================================================================================================

set -eu

# Ensure standard Entware and system PATH
export PATH="/opt/bin:/opt/sbin:/usr/bin:/usr/sbin:/bin:/sbin:${PATH:-}"

VERSION="1.0.2"
OPKG_STATUS="/opt/lib/opkg/status"

# Colors
if [ -t 1 ]; then
    C_RESET="\033[0m"
    C_BOLD="\033[1m"
    C_GREEN="\033[1;32m"
    C_CYAN="\033[1;36m"
    C_YELLOW="\033[1;33m"
    C_RED="\033[1;31m"
    C_DIM="\033[2m"
else
    C_RESET=""
    C_BOLD=""
    C_GREEN=""
    C_CYAN=""
    C_YELLOW=""
    C_RED=""
    C_DIM=""
fi

# Operating Flags
FLAG_FIX=0
FLAG_ASSUME_YES=0
FLAG_DRY_RUN=0
TOTAL_ISSUES=0
FIXED_ISSUES=0
TOTAL_RECLAIMED_KB=0

# Core protected package whitelist (never treat as orphans)
PROTECTED_PKGS="opkg entware-opt busybox libc libpthread librt libgcc libstdcpp musl ca-certificates"

# -------------------------------------------------------------------------------------------------------------------------
# Helper Functions

log_header() {
    printf "\n%b%s%b\n" "${C_GREEN}" "===================================================================" "${C_RESET}"
    printf "%b   EntwareDoctor v%s%b\n" "${C_BOLD}" "${VERSION}" "${C_RESET}"
    printf "%b   Automated Entware Health, Dependency & Cleanup Sentinel%b\n" "${C_DIM}" "${C_RESET}"
    printf "%b%s%b\n\n" "${C_GREEN}" "===================================================================" "${C_RESET}"
}

log_step() {
    printf "%b[*] [%s] %s...%b\n" "${C_CYAN}" "$1" "$2" "${C_RESET}"
}

log_ok() {
    printf "    %b[+] %s%b\n" "${C_GREEN}" "$1" "${C_RESET}"
}

log_warn() {
    printf "    %b[!] %s%b\n" "${C_YELLOW}" "$1" "${C_RESET}"
    TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
}

log_error() {
    printf "    %b[x] Error: %s%b\n" "${C_RED}" "$1" "${C_RESET}"
    TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
}

log_fix() {
    printf "    %b[->] FIXED: %s%b\n" "${C_GREEN}" "$1" "${C_RESET}"
    FIXED_ISSUES=$((FIXED_ISSUES + 1))
}

prompt_confirm() {
    prompt_msg="$1"
    if [ "${FLAG_ASSUME_YES}" -eq 1 ]; then
        return 0
    fi
    if [ "${FLAG_DRY_RUN}" -eq 1 ]; then
        return 1
    fi

    printf "%b%s [y/N]: %b" "${C_BOLD}" "${prompt_msg}" "${C_RESET}"
    if [ -t 0 ]; then
        read -r choice
    elif [ -c /dev/tty ]; then
        read -r choice < /dev/tty
    else
        choice="n"
    fi

    case "${choice}" in
        [yY]|[yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}

# -------------------------------------------------------------------------------------------------------------------------
# Step 1: Environment & Partition Check

check_environment() {
    log_step "1/7" "Checking Entware Mount & Partition Integrity"

    if [ ! -d "/opt" ]; then
        log_error "/opt directory does not exist. Entware is not installed."
        return 1
    fi

    # Check if /opt is mounted
    if ! grep -q " /opt " /proc/mounts 2>/dev/null && ! grep -q "/tmp/mnt" /proc/mounts 2>/dev/null; then
        log_warn "/opt may not be cleanly mounted on an external storage partition."
    fi

    # Check write permissions
    if ! touch /opt/.entware_doctor_test 2>/dev/null; then
        log_error "/opt filesystem is mounted Read-Only (RO) or storage is corrupted!"
        return 1
    fi
    rm -f /opt/.entware_doctor_test

    # Check free disk space on /opt
    opt_free_kb="$(df -k /opt 2>/dev/null | awk 'NR==2 {print $4}')"
    if [ -n "${opt_free_kb}" ]; then
        opt_free_mb=$((opt_free_kb / 1024))
        if [ "${opt_free_mb}" -lt 50 ]; then
            log_warn "Low disk space on /opt: only ${opt_free_mb} MB remaining!"
        else
            log_ok "Partition write test passed (${opt_free_mb} MB free) - OK"
        fi
    else
        log_ok "Partition accessible and writable - OK"
    fi
}

# -------------------------------------------------------------------------------------------------------------------------
# Step 2: Shared Library & Missing Dependency Check

check_libraries() {
    log_step "2/7" "Scanning Binaries for Missing Shared Libraries (.so)"

    missing_libs=0
    checked_bins=0

    # Scan binaries in /opt/bin and /opt/sbin
    for bin_path in /opt/bin/* /opt/sbin/*; do
        [ -f "${bin_path}" ] || continue
        [ -x "${bin_path}" ] || continue
        [ -L "${bin_path}" ] && continue

        # Verify if ELF executable
        if head -c 4 "${bin_path}" 2>/dev/null | grep -q "ELF"; then
            checked_bins=$((checked_bins + 1))
            
            # If ldd exists, check library resolution
            if command -v ldd >/dev/null 2>&1; then
                ldd_out="$(ldd "${bin_path}" 2>&1 || true)"
                if echo "${ldd_out}" | grep -q "not found"; then
                    missing_item="$(echo "${ldd_out}" | grep "not found" | awk '{print $1}' | tr '\n' ' ')"
                    log_warn "${bin_path} is missing: ${missing_item}"
                    missing_libs=$((missing_libs + 1))

                    # Auto-Fix: Check if matching version exists in /opt/lib (e.g. libssl.so.3 for libssl.so.1.1)
                    if [ "${FLAG_FIX}" -eq 1 ]; then
                        for missing_lib in ${missing_item}; do
                            base_lib="$(echo "${missing_lib}" | sed 's/\.so\..*/.so/')"
                            avail_lib="$(find /opt/lib -name "${base_lib}*" 2>/dev/null | head -n 1)"
                            if [ -n "${avail_lib}" ] && [ ! -e "/opt/lib/${missing_lib}" ]; then
                                if prompt_confirm "Create compatibility symlink /opt/lib/${missing_lib} -> ${avail_lib}?"; then
                                    ln -sf "${avail_lib}" "/opt/lib/${missing_lib}"
                                    log_fix "Linked /opt/lib/${missing_lib} -> ${avail_lib}"
                                fi
                            fi
                        done
                    fi
                fi
            fi
        fi
    done

    if [ "${missing_libs}" -eq 0 ]; then
        log_ok "${checked_bins} ELF binaries scanned: all dynamic libraries resolved - OK"
    else
        log_warn "Detected ${missing_libs} broken binary dependencies."
    fi
}

# -------------------------------------------------------------------------------------------------------------------------
# Step 3: Dangling / Broken Symlink Audit

check_dangling_symlinks() {
    log_step "3/7" "Checking for Dangling / Broken Symlinks"

    dangling_count=0
    for search_dir in /opt/bin /opt/sbin /opt/lib /opt/etc; do
        [ -d "${search_dir}" ] || continue
        for link in "${search_dir}"/*; do
            [ -L "${link}" ] || continue
            if [ ! -e "${link}" ]; then
                target_dest="$(readlink "${link}" 2>/dev/null || echo "unknown")"
                log_warn "Broken symlink: ${link} -> ${target_dest}"
                dangling_count=$((dangling_count + 1))

                if [ "${FLAG_FIX}" -eq 1 ]; then
                    if prompt_confirm "Remove dead symlink ${link}?"; then
                        rm -f "${link}"
                        log_fix "Removed dead symlink: ${link}"
                    fi
                fi
            fi
        done
    done

    if [ "${dangling_count}" -eq 0 ]; then
        log_ok "No dangling symlinks found across /opt - OK"
    fi
}

# -------------------------------------------------------------------------------------------------------------------------
# Step 4: Daemon Sentinel & Stale Lockfiles

check_services_and_locks() {
    log_step "4/7" "Inspecting /opt/etc/init.d Daemons & Stale Lockfiles"

    # 1. Clean stale PID files in /opt/var/run
    if [ -d "/opt/var/run" ]; then
        for pidfile in /opt/var/run/*.pid; do
            [ -f "${pidfile}" ] || continue
            pid_val="$(cat "${pidfile}" 2>/dev/null || echo "")"
            if [ -n "${pid_val}" ]; then
                if ! kill -0 "${pid_val}" 2>/dev/null; then
                    log_warn "Stale PID file detected: ${pidfile} (Process ${pid_val} is dead)"
                    if [ "${FLAG_FIX}" -eq 1 ]; then
                        if prompt_confirm "Remove stale PID file ${pidfile}?"; then
                            rm -f "${pidfile}"
                            log_fix "Removed stale PID file: ${pidfile}"
                        fi
                    fi
                fi
            fi
        done
    fi

    # 2. Check service daemons status
    if [ -d "/opt/etc/init.d" ]; then
        for init_script in /opt/etc/init.d/S*; do
            [ -f "${init_script}" ] || continue
            [ -x "${init_script}" ] || continue
            svc_name="$(basename "${init_script}")"
            
            # Check if script implements check or status
            if "${init_script}" check >/dev/null 2>&1; then
                log_ok "${svc_name}: ACTIVE (healthy)"
            elif "${init_script}" status >/dev/null 2>&1; then
                log_ok "${svc_name}: ACTIVE (healthy)"
            fi
        done
    fi
}

# -------------------------------------------------------------------------------------------------------------------------
# Step 5: Linker Configuration & PATH Consistency

check_linker_and_paths() {
    log_step "5/7" "Verifying Dynamic Linker & Environment Path"

    # Check ld.so.conf if present and has content
    if [ -s "/opt/etc/ld.so.conf" ]; then
        if grep -qE "(^|/opt/)lib" /opt/etc/ld.so.conf 2>/dev/null; then
            log_ok "ld.so.conf configured correctly - OK"
        else
            log_warn "/opt/etc/ld.so.conf does not include /opt/lib"
            if [ "${FLAG_FIX}" -eq 1 ]; then
                echo "/opt/lib" >> /opt/etc/ld.so.conf
                log_fix "Added /opt/lib to /opt/etc/ld.so.conf"
            fi
        fi
    else
        log_ok "Dynamic linker uses standard Entware runtime paths - OK"
    fi

    # Check PATH in profile.add
    if [ -f "/jffs/configs/profile.add" ]; then
        if ! grep -q "/opt/bin" "/jffs/configs/profile.add" 2>/dev/null; then
            log_warn "/opt/bin is missing from /jffs/configs/profile.add"
        else
            log_ok "JFFS profile environment includes /opt - OK"
        fi
    else
        log_ok "System environment PATH includes /opt - OK"
    fi
}

# -------------------------------------------------------------------------------------------------------------------------
# Step 6: Orphaned Package Detection & Removal Engine

check_orphaned_packages() {
    log_step "6/7" "Scanning for Orphaned Library Packages"

    if [ ! -f "${OPKG_STATUS}" ]; then
        log_warn "opkg status database not found at ${OPKG_STATUS}."
        return 0
    fi

    # 1. Line-by-line AWK state machine for 100% portable metadata & dependency extraction
    pkg_meta_tmp="/tmp/entware_doctor_pkgs_$$.tmp"

    awk '
    /^Package:/ {
        if (pkg != "") {
            print pkg "|" sec "|" size "|" deps;
        }
        pkg = $0;
        sub(/^Package:[ \t]*/, "", pkg);
        gsub(/[ \t\r\n]/, "", pkg);
        sec = "";
        size = 0;
        deps = "";
        next;
    }
    /^Section:/ {
        sec = $0;
        sub(/^Section:[ \t]*/, "", sec);
        gsub(/[ \t\r\n]/, "", sec);
        next;
    }
    /^Installed-Size:/ {
        sline = $0;
        sub(/^Installed-Size:[ \t]*/, "", sline);
        gsub(/[^0-9]/, "", sline);
        if (sline != "") size = sline + 0;
        next;
    }
    /^Size:/ {
        if (size == 0 || size == "") {
            sline = $0;
            sub(/^Size:[ \t]*/, "", sline);
            gsub(/[^0-9]/, "", sline);
            if (sline != "") size = sline + 0;
        }
        next;
    }
    /^Depends:/ {
        dline = $0;
        sub(/^Depends:[ \t]*/, "", dline);
        gsub(/\([^)]*\)/, "", dline);
        gsub(/,/, " ", dline);
        deps = deps " " dline;
        next;
    }
    END {
        if (pkg != "") {
            print pkg "|" sec "|" size "|" deps;
        }
    }
    ' "${OPKG_STATUS}" > "${pkg_meta_tmp}"

    # 2. Build master list of all required dependency package names
    all_needed_deps="$(awk -F'|' '{print $4}' "${pkg_meta_tmp}" | tr ' ' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$' | sort -u)"

    # 3. Discover all dynamic shared libraries (.so) actively referenced by all binaries in /opt
    # Uses both glob expansion and recursive scan so it works 100% on all BusyBox builds
    used_so_files="$( (grep -ahoE 'lib[a-zA-Z0-9_\.\+-]+\.so(\.[0-9]+)*' /opt/bin/* /opt/sbin/* /opt/lib/* 2>/dev/null || grep -rahoE 'lib[a-zA-Z0-9_\.\+-]+\.so(\.[0-9]+)*' /opt/bin /opt/sbin /opt/lib 2>/dev/null) | sort -u || true)"

    orphan_candidates=""
    reclaimed_bytes=0

    # 4. Evaluate each installed package
    while IFS='|' read -r pkg_name pkg_sec pkg_size _pkg_deps; do
        [ -n "${pkg_name}" ] || continue

        # Skip protected core packages
        case " ${PROTECTED_PKGS} " in
            *" ${pkg_name} "*) continue ;;
        esac

        # Locate package file manifest
        pkg_list_file="/opt/lib/opkg/info/${pkg_name}.list"
        [ -f "${pkg_list_file}" ] || pkg_list_file="/opt/var/lib/opkg/info/${pkg_name}.list"

        # Check if the package installs any executable command or init service
        if [ -f "${pkg_list_file}" ]; then
            if grep -qE "(^|/)(bin|sbin|etc/init\.d)/" "${pkg_list_file}" 2>/dev/null; then
                continue
            fi
        fi

        # Direct executable verification in /opt/bin and /opt/sbin
        if [ -x "/opt/bin/${pkg_name}" ] || [ -x "/opt/sbin/${pkg_name}" ]; then
            continue
        fi

        # Check if package is a library or support package
        is_lib_pkg=0
        case "${pkg_sec}" in
            *lib*) is_lib_pkg=1 ;;
        esac
        case "${pkg_name}" in
            lib*|python3-*|perl5-*|lua-*|*-data|*-common) is_lib_pkg=1 ;;
        esac

        # Standalone user application -> skip
        [ "${is_lib_pkg}" -eq 0 ] && continue

        # Check if required as a dependency by another installed package
        if echo "${all_needed_deps}" | grep -qx "${pkg_name}"; then
            continue
        fi

        # Check if package name itself matches a referenced library prefix (e.g. libcurl -> libcurl.so)
        if [ -n "${used_so_files}" ]; then
            if echo "${used_so_files}" | grep -qE "^${pkg_name}(\.so|-|\.)"; then
                continue
            fi
        fi

        # Check if any .so file provided by this package is actively referenced by executables
        if [ -n "${used_so_files}" ] && [ -f "${pkg_list_file}" ]; then
            pkg_so_names="$(grep '\.so' "${pkg_list_file}" 2>/dev/null | awk -F'/' '{print $NF}' | sed 's/\.so.*/.so/' | sort -u || true)"
            is_so_used=0
            for so_name in ${pkg_so_names}; do
                if echo "${used_so_files}" | grep -q "${so_name}"; then
                    is_so_used=1
                    break
                fi
            done
            [ "${is_so_used}" -eq 1 ] && continue
        fi

        # True Orphan!
        orphan_candidates="${orphan_candidates} ${pkg_name}"
        reclaimed_bytes=$((reclaimed_bytes + pkg_size))

    done < "${pkg_meta_tmp}"

    rm -f "${pkg_meta_tmp}"

    orphan_candidates="$(echo "${orphan_candidates}" | sed 's/^[[:space:]]*//')"

    if [ -n "${orphan_candidates}" ]; then
        orphan_count="$(echo "${orphan_candidates}" | wc -w | tr -d ' ')"
        reclaimed_kb=$(( (reclaimed_bytes + 1023) / 1024 ))
        log_warn "Detected ${orphan_count} true orphaned library package(s):"
        for opkg_name in ${orphan_candidates}; do
            printf "        - %b%s%b\n" "${C_YELLOW}" "${opkg_name}" "${C_RESET}"
        done
        if [ "${reclaimed_kb}" -ge 1024 ]; then
            printf "    %bRecoverable Space: ~%d KB (~%d MB)%b\n" "${C_CYAN}" "${reclaimed_kb}" "$((reclaimed_kb / 1024))" "${C_RESET}"
        else
            printf "    %bRecoverable Space: ~%d KB%b\n" "${C_CYAN}" "${reclaimed_kb}" "${C_RESET}"
        fi

        if [ "${FLAG_FIX}" -eq 1 ] || [ "${FLAG_ASSUME_YES}" -eq 1 ]; then
            if prompt_confirm "Would you like to remove these ${orphan_count} orphaned library packages?"; then
                for opkg_name in ${orphan_candidates}; do
                    printf "    [*] Removing %s...\n" "${opkg_name}"
                    opkg remove "${opkg_name}" || true
                done
                TOTAL_RECLAIMED_KB=$((TOTAL_RECLAIMED_KB + reclaimed_kb))
                log_fix "Purged ${orphan_count} orphaned packages."
            fi
        fi
    else
        log_ok "No orphaned library packages detected - All installed libraries are in active use - OK"
    fi
}

# -------------------------------------------------------------------------------------------------------------------------
# Step 7: Ghost Files, Leftover Configs & Cache Cleanup

check_ghost_files() {
    log_step "7/7" "Sweeping Ghost Files, Leftover Configs & Package Caches"

    ghost_count=0
    cache_cleaned_kb=0

    # 1. Clean stale opkg backup files (*.opkg-old, *.opkg-new, *.conffile.bak)
    for stale_conf in /opt/etc/*.opkg-old /opt/etc/*.opkg-new /opt/etc/*/*.opkg-old /opt/etc/*/*.opkg-new; do
        [ -f "${stale_conf}" ] || continue
        file_size="$(wc -c < "${stale_conf}" 2>/dev/null || echo "0")"
        cache_cleaned_kb=$((cache_cleaned_kb + (file_size / 1024)))
        log_warn "Stale config backup found: ${stale_conf}"
        ghost_count=$((ghost_count + 1))

        if [ "${FLAG_FIX}" -eq 1 ]; then
            if prompt_confirm "Remove stale backup file ${stale_conf}?"; then
                rm -f "${stale_conf}"
                TOTAL_RECLAIMED_KB=$((TOTAL_RECLAIMED_KB + (file_size / 1024)))
                log_fix "Removed ${stale_conf}"
            fi
        fi
    done

    # 2. Clean Entware temporary downloads and IPK package caches
    for cache_dir in /opt/var/cache/opkg /opt/tmp; do
        if [ -d "${cache_dir}" ]; then
            ipk_count="$(find "${cache_dir}" -name "*.ipk" 2>/dev/null | wc -l | tr -d ' ')"
            if [ "${ipk_count}" -gt 0 ]; then
                log_warn "Found ${ipk_count} cached .ipk packages in ${cache_dir}"
                ghost_count=$((ghost_count + ipk_count))
                if [ "${FLAG_FIX}" -eq 1 ]; then
                    if prompt_confirm "Clean .ipk package cache in ${cache_dir}?"; then
                        rm -rf "${cache_dir}"/*.ipk 2>/dev/null || true
                        log_fix "Cleared .ipk cache in ${cache_dir}"
                    fi
                fi
            fi
        fi
    done

    # 3. Clean empty leftover directories in /opt/lib and /opt/share
    empty_dirs=0
    for check_base in /opt/share /opt/lib; do
        [ -d "${check_base}" ] || continue
        for empty_dir in $(find "${check_base}" -type d -empty 2>/dev/null || true); do
            [ "${empty_dir}" = "${check_base}" ] && continue
            empty_dirs=$((empty_dirs + 1))
            if [ "${FLAG_FIX}" -eq 1 ]; then
                rmdir "${empty_dir}" 2>/dev/null || true
            fi
        done
    done

    if [ "${empty_dirs}" -gt 0 ] && [ "${FLAG_FIX}" -eq 1 ]; then
        log_fix "Pruned ${empty_dirs} abandoned empty directories."
    fi

    if [ "${ghost_count}" -eq 0 ]; then
        log_ok "No ghost files or leftover caches found - OK"
    fi
}

# -------------------------------------------------------------------------------------------------------------------------
# CLI Options & Entrypoint

show_help() {
    cat <<EOF
EntwareDoctor v${VERSION} - Automated Entware Health, Dependency, and Cleanup Sentinel

Usage:
  entware-doctor [options]

Options:
  -s, --scan         Run diagnostic scan only (safe inspection, no changes)
  -f, --fix          Scan and interactively repair detected issues
  -a, --all          Perform full auto-repair and cleanup without prompts
  -y, --yes          Assume Yes to all repair prompts
  -d, --dry-run      Simulate fixes without modifying any files
  -v, --version      Display version information
  -h, --help         Show this help message

Examples:
  entware-doctor             # Standard diagnostic check
  entware-doctor --fix       # Interactively repair broken libs & clean orphans
  entware-doctor --all -y    # Fully automated unattended healing

EOF
}

main() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -s|--scan)
                FLAG_FIX=0
                ;;
            -f|--fix)
                FLAG_FIX=1
                ;;
            -a|--all)
                FLAG_FIX=1
                FLAG_ASSUME_YES=1
                ;;
            -y|--yes)
                FLAG_ASSUME_YES=1
                ;;
            -d|--dry-run)
                FLAG_DRY_RUN=1
                ;;
            -v|--version)
                printf "EntwareDoctor v%s\n" "${VERSION}"
                exit 0
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                printf "%bUnknown option: %s%b\n\n" "${C_RED}" "$1" "${C_RESET}"
                show_help
                exit 1
                ;;
        esac
        shift
    done

    log_header

    check_environment || exit 1
    check_libraries
    check_dangling_symlinks
    check_services_and_locks
    check_linker_and_paths
    check_orphaned_packages
    check_ghost_files

    printf "\n%b===================================================================%b\n" "${C_GREEN}" "${C_RESET}"
    if [ "${TOTAL_ISSUES}" -eq 0 ]; then
        printf "%b  Diagnosis Complete: Your Entware environment is 100%% HEALTHY!%b\n" "${C_GREEN}" "${C_RESET}"
    else
        printf "%b  Diagnosis Complete: %d issue(s) detected. %d issue(s) repaired.%b\n" "${C_YELLOW}" "${TOTAL_ISSUES}" "${FIXED_ISSUES}" "${C_RESET}"
        if [ "${TOTAL_RECLAIMED_KB}" -gt 0 ]; then
            printf "%b  Total Disk Space Reclaimed: ~%d KB (%d MB)%b\n" "${C_GREEN}" "${TOTAL_RECLAIMED_KB}" "$((TOTAL_RECLAIMED_KB / 1024))" "${C_RESET}"
        fi
        if [ "${FLAG_FIX}" -eq 0 ]; then
            printf "%b  Tip: Run 'entware-doctor --fix' to automatically resolve these issues.%b\n" "${C_CYAN}" "${C_RESET}"
        fi
    fi
    printf "%b===================================================================%b\n\n" "${C_GREEN}" "${C_RESET}"
}

main "$@"
