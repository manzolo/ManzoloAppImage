# shellcheck shell=bash
# Shared helpers sourced by build-in-docker.sh, wizard.sh, and each
# example's build.sh. Keep it dependency-free (pure bash + coreutils).

# ----- color output --------------------------------------------------------
if [[ -t 1 ]] && [[ "${NO_COLOR:-0}" != "1" ]]; then
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_DIM=$'\033[2m'
    C_RED=$'\033[31m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_BLUE=$'\033[34m'
    C_CYAN=$'\033[36m'
else
    C_RESET=""
    C_BOLD=""
    C_DIM=""
    C_RED=""
    C_GREEN=""
    C_YELLOW=""
    C_BLUE=""
    C_CYAN=""
fi

log_info()  { printf '%s\n' "${C_BLUE}==>${C_RESET} ${C_BOLD}$*${C_RESET}"; }
log_ok()    { printf '%s\n' "${C_GREEN}OK${C_RESET}  $*"; }
log_warn()  { printf '%s\n' "${C_YELLOW}WARN${C_RESET} $*" >&2; }
log_error() { printf '%s\n' "${C_RED}ERR${C_RESET}  $*" >&2; }

# ----- prompt helpers ------------------------------------------------------
# confirm "Prompt question" [default-y|default-n]
confirm() {
    local prompt="$1"
    local default="${2:-y}"
    local suffix
    if [[ "$default" == "y" ]]; then suffix="[Y/n]"; else suffix="[y/N]"; fi
    local reply
    read -r -p "$prompt $suffix " reply || return 1
    reply="${reply,,}"
    if [[ -z "$reply" ]]; then reply="$default"; fi
    [[ "$reply" == "y" || "$reply" == "yes" ]]
}

# ----- AppDir helpers ------------------------------------------------------
# Generate a placeholder 256x256 PNG icon if one doesn't already exist.
# Usage: ensure_icon <output-png> <single-letter> <hex-bg> <hex-fg>
ensure_icon() {
    local out="$1" letter="$2" bg="${3:-#1e88e5}" fg="${4:-#ffffff}"
    [[ -f "$out" ]] && return 0
    if ! command -v convert >/dev/null; then
        log_error "ImageMagick 'convert' not found — cannot generate icon $out"
        return 1
    fi
    convert -size 256x256 "xc:${bg}" \
        -fill "$fg" -gravity center -font DejaVu-Sans-Bold -pointsize 180 \
        -annotate +0+0 "$letter" \
        "$out"
}

# Verify required AppDir pieces are present.
# Usage: validate_appdir <AppDir-path>
validate_appdir() {
    local d="$1"
    local missing=0
    for f in AppRun *.desktop; do
        if ! compgen -G "$d/$f" >/dev/null; then
            log_error "AppDir is missing: $f"
            missing=1
        fi
    done
    if ! compgen -G "$d/*.png" >/dev/null; then
        log_error "AppDir is missing an icon (*.png at root)"
        missing=1
    fi
    return "$missing"
}
