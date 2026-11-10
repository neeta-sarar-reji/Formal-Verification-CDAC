# Source this file:  source scripts/env.sh
# Adjust OSS_CAD if your install path differs.
export OSS_CAD="${OSS_CAD:-$HOME/Downloads/oss-cad-suite}"
source "$OSS_CAD/environment"
export REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export EXT="$REPO_ROOT/external"
