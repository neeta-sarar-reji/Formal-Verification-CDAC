export OSS_CAD="${OSS_CAD:-$HOME/Downloads/oss-cad-suite}"
[ -f "$OSS_CAD/environment" ] && source "$OSS_CAD/environment"
export REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export EXT="$REPO_ROOT/external"
