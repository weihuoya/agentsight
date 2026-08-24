#!/bin/bash
set -euo pipefail

# Helper script to build AgentSight from the local git checkout.
# Usage: ./build-local.sh [-i|--install]
#   -i, --install  Build and install the package

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

INSTALL=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        -i|--install)
            INSTALL=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [-i|--install]"
            exit 1
            ;;
    esac
done

# The pkg/ directory is expected to live directly under the repository root.
# Derive GITROOT from the script location so we do not depend on git being
# configured inside containers (safe.directory, etc.).
GITROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
if [[ ! -f "$GITROOT/collector/Cargo.toml" ]]; then
    echo "ERROR: This script must be run from inside the AgentSight git repository."
    exit 1
fi

echo "Building AgentSight from local source: $GITROOT"
echo ""

# Use a build directory under this script's directory so makepkg's
# temporary src/pkg directories (and the final .pkg.tar.* file unless
# PKGDEST is set) are isolated from the rest of the repository.
export BUILDDIR="${BUILDDIR:-$SCRIPT_DIR/.build}"
mkdir -p "$BUILDDIR"
echo "Build directory: $BUILDDIR"
echo ""

if [[ "$INSTALL" == true ]]; then
    makepkg -sfi
else
    makepkg -sf
fi

echo ""
echo "Build complete. Package:"
ls -la "$SCRIPT_DIR"/agentsight-*.pkg.tar.* 2>/dev/null || true
