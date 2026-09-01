# 🩺 EntwareDoctor

**Automated Health, Missing Dependency & Orphan Package Sentinel for Entware on Asuswrt-Merlin.**

[![License: GPL-3.0](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Asuswrt-Merlin](https://img.shields.io/badge/Asuswrt--Merlin-386%20%7C%20388%20%7C%203006-brightgreen.svg)](https://www.asuswrt-merlin.net/)
[![Platform](https://img.shields.io/badge/Platform-ARMv7%20%7C%20ARM64%20%7C%20HND-orange.svg)](https://github.com/Entware/Entware)

---

## 🌟 Why EntwareDoctor?

Over months of uptime, package installations, and `opkg upgrade` cycles, Entware environments on Asuswrt-Merlin routers frequently degrade:
* **Missing Shared Libraries (`.so`):** Upgrading core libraries (e.g. OpenSSL or glibc) leaves existing compiled tools or Python/Go scripts failing with `cannot open shared object file: No such file or directory`.
* **Accumulated Orphan Packages:** Uninstalling a package via `opkg` leaves its dependencies behind indefinitely, wasting valuable space.
* **Dangling Symlinks & Ghost Files:** Stale backup files (`*.opkg-old`, `*.opkg-new`), broken symlinks, and orphaned `.ipk` package caches litter `/opt`.
* **Stale Daemons & Lockfiles:** Crashed services leave behind stale `.pid` files and locks in `/opt/var/run/`, blocking daemons from auto-starting.

**EntwareDoctor** is a lightweight, zero-dependency diagnostic and self-healing tool that scans, repairs, and optimizes your Entware installation in seconds.

---

## ⚡ 1-Line Installation

Run the following command over SSH on your Asuswrt-Merlin router:

```bash
curl -fsSL https://raw.githubusercontent.com/underd0se/EntwareDoctor/main/install.sh | sh
```

---

## 🚀 Usage & Commands

### 1. Standard Diagnostic Scan (Safe Inspection / Dry-Run)
Inspects the entire Entware environment and reports all issues without making any modifications:

```bash
entware-doctor
```

### 2. Interactive Auto-Repair & Cleanup
Scans and prompts you before repairing broken libraries, purging orphans, or clearing stale files:

```bash
entware-doctor --fix
```

### 3. Unattended Automated Healing
Performs full repairs and cleans orphaned packages automatically (ideal for scheduled cron maintenance):

```bash
entware-doctor --all --yes
```

---

## 🔍 What EntwareDoctor Inspects & Repairs

```
[1/7] 📂 Partition & Mount Health  : Tests /opt read/write integrity and free storage space.
[2/7] 🔗 Missing Shared Libraries   : Scans all ELF binaries for unresolved dynamic .so dependencies.
[3/7] ⛓️ Dangling Symlink Audit    : Discovers and repairs broken symlinks in /opt/bin, /opt/sbin, /opt/lib.
[4/7] 🛡️ Daemon & Lockfile Sentinel: Detects stale PID files and validates /opt/etc/init.d services.
[5/7] 🧭 Linker & Environment Path : Ensures /opt/lib is registered in ld.so.conf and profile.add.
[6/7] 📦 Orphaned Package Purge    : Builds reverse dependency graphs to safely identify and prune unneeded packages.
[7/7] 🧹 Ghost File & Cache Sweep  : Purges *.opkg-old configs, cached .ipk files, and abandoned directories.
```

---

## 🛡️ Safety & Whitelisting

* **Protected Core Packages:** Essential system packages (`opkg`, `busybox`, `libc`, `ca-certificates`, etc.) and all known Asuswrt-Merlin add-ons (`amtm`, `diversion`, `skynet`, `zeroscale`, `scribe`, `yazfi`, etc.) are whitelisted and never flagged as orphans.
* **Interactive Confirmation:** Destructive operations always require explicit confirmation (`[y/N]`) unless `--yes` is passed.
* **Zero Flash Wear:** All temporary diagnostic checks execute in RAM (`/tmp`).

---

## 📄 License

EntwareDoctor is open-source software licensed under the **GNU General Public License v3.0 (GPLv3)**.
