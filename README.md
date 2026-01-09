# Startup

Bootstrap script for setting up development environments on macOS and Linux.

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/blubblub/startup/main/startup.sh | bash
```

## What it does

- Installs **Git** (via Xcode CLT on macOS, package managers on Linux)
- Installs **Docker** (Docker Desktop on macOS, Docker Engine on Linux)
- Optionally clones a repository and runs its install script

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `REPO_URL` | Git repository to clone | (prompts if not set) |
| `INSTALL_DIR` | Target directory for cloned repo | `$HOME/project` |
| `BRANCH` | Branch to checkout | `main` |

## Examples

```bash
# Interactive mode (prompts for repo URL)
curl -fsSL https://raw.githubusercontent.com/blubblub/startup/main/startup.sh | bash

# Clone a specific repository
curl -fsSL https://raw.githubusercontent.com/blubblub/startup/main/startup.sh | REPO_URL="git@github.com:org/repo.git" bash

# Full customization
curl -fsSL https://raw.githubusercontent.com/blubblub/startup/main/startup.sh | \
  REPO_URL="git@github.com:org/repo.git" \
  INSTALL_DIR="$HOME/myproject" \
  BRANCH="develop" \
  bash
```

## License

MIT
