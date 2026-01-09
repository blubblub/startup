# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Overview

This is a **bootstrap script** (`startup.sh`) for setting up development environments on macOS and Linux. It automates installation of:
- Git (via Xcode CLT on macOS, package managers on Linux)
- Docker (Docker Desktop on macOS, Docker Engine on Linux)
- Optional: cloning a repository and running its install script

## Running the Script

```bash
# Basic usage (interactive - prompts for repo URL)
./startup.sh

# With environment variables (non-interactive)
REPO_URL="git@github.com:org/repo.git" INSTALL_DIR="$HOME/myproject" BRANCH="develop" ./startup.sh
```

## Environment Variables

- `REPO_URL` - Git repository to clone (optional)
- `INSTALL_DIR` - Target directory for cloned repo (default: `$HOME/project`)
- `BRANCH` - Branch to checkout (default: `main`)

## Architecture

Single-file shell script with these main components:
- **OS/Package Detection**: `detect_os()`, `detect_package_manager()`
- **Git Installation**: `ensure_git()` → delegates to `install_git_macos()` or `install_git_linux()`
- **Docker Installation**: `ensure_docker()` → delegates to `install_docker_macos()` or `install_docker_linux()`
- **Repository Setup**: `clone_repository()`, `run_install_script()` (looks for `scripts/install.sh` in cloned repo)

The script uses `set -e` to exit on any error and colored logging functions (`log_info`, `log_success`, `log_warn`, `log_error`).
