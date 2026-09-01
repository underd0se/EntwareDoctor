# Changelog ─ EntwareDoctor

All notable changes to the EntwareDoctor project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
