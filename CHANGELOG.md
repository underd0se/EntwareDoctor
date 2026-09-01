# Changelog ─ EntwareDoctor

All notable changes to the EntwareDoctor project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.2] - 2026-09-01

### 🛠️ Enhanced Binary Scan with Glob & Recursive Matching

* **Glob & Recursive SO Scanner:** Fixed binary directory inspection by supporting both glob expansion (`/opt/bin/*`, `/opt/sbin/*`) and recursive `-r` scanning, correctly resolving all dynamically loaded shared libraries.
* **Exact Size Accumulator:** Enhanced `Installed-Size` numeric extraction and human-readable KB/MB space calculations.

---

## [1.0.1] - 2026-09-01

### 🛠️ Smart Package Classification & State-Machine Metadata Parser

* **Executable & Service Whitelist Filter:** Automatically excludes any package that installs an executable command in `/opt/bin/`, `/opt/sbin/`, or a service in `/opt/etc/init.d/`, protecting user-installed tools (`htop`, `micro`, `ripgrep`, `tailscale`, etc.).
* **State-Machine AWK Parser:** Line-by-line parser for `/opt/lib/opkg/status` ensuring 100% portable metadata and dependency extraction across BusyBox ash and standard awk.
* **CDN Cache Busting:** Added `?nocache` query timestamp to universal installer downloads preventing stale CDN caching.
* **Refined Dynamic Linker Check:** Gracefully handles standard system runtime paths when `/opt/etc/ld.so.conf` is empty.

---

## [1.0.0] - 2026-09-01

### 🚀 Initial Production Release

* **Partition & Storage Verification:** Validates `/opt` read/write permissions, mount point consistency, and available storage space.
* **Missing Dynamic Library Scanner:** Scans ELF binaries in `/opt/bin` and `/opt/sbin` to detect unresolved `.so` shared libraries and automatically provision compatibility symlinks.
* **Dangling Symlink Purge:** Discovers and cleans up broken symlinks across `/opt/bin`, `/opt/sbin`, `/opt/lib`, and `/opt/etc`.
* **Service Daemon Sentinel:** Inspects `/opt/etc/init.d/` daemons and clears stale `.pid` files from `/opt/var/run/`.
* **Dynamic Linker & PATH Audit:** Ensures `/opt/lib` is loaded in `/opt/etc/ld.so.conf` and exported in `/jffs/configs/profile.add`.
* **Orphaned Package Dependency Graph Engine:** Identifies and safely purges leaf packages that have 0 reverse dependencies in `opkg`.
* **Ghost File & Cache Cleaner:** Cleans stale `*.opkg-old` / `*.opkg-new` configuration remnants, `.ipk` temporary package archives, and empty directories.
* **Non-Destructive Dry-Run & Interactive Repair Modes:** Includes `--scan`, `--fix`, and `--all` modes with safety whitelisting.
