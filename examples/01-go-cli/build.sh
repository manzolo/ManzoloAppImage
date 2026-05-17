#!/usr/bin/env bash
# Build the Go CLI AppImage.
#
# This is the simplest possible AppImage:
#  - Go produces a single static binary (no .so dependencies).
#  - We assemble an AppDir with: AppRun + .desktop + icon + the binary.
#  - appimagetool packs the AppDir into a single .AppImage file.
#
# Intended to be run inside the manzolo-appimage-builder Docker image,
# but also works on any host with Go + appimagetool in PATH.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source=../../scripts/common.sh
source "${REPO_ROOT}/scripts/common.sh"

APP_NAME="HelloGo"
BIN_NAME="hello-go"
APPDIR="${SCRIPT_DIR}/AppDir"
OUT_DIR="${REPO_ROOT}/out"

log_info "Cleaning previous build"
rm -rf "$APPDIR" "${SCRIPT_DIR}/${APP_NAME}-x86_64.AppImage"

log_info "Compiling Go binary (static)"
mkdir -p "${APPDIR}/usr/bin"
( cd "$SCRIPT_DIR" && CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" \
    -o "${APPDIR}/usr/bin/${BIN_NAME}" . )

log_info "Generating placeholder icon (256x256)"
ensure_icon "${SCRIPT_DIR}/${BIN_NAME}.png" "G" "#00ADD8" "#ffffff"

log_info "Assembling AppDir"
# .desktop and icon at the AppDir root (appimagetool convention).
cp "${SCRIPT_DIR}/${BIN_NAME}.desktop" "${APPDIR}/${BIN_NAME}.desktop"
cp "${SCRIPT_DIR}/${BIN_NAME}.png"     "${APPDIR}/${BIN_NAME}.png"

# Also place them at the standard XDG locations so desktop environments
# pick them up after the AppImage is integrated.
mkdir -p "${APPDIR}/usr/share/applications" \
         "${APPDIR}/usr/share/icons/hicolor/256x256/apps"
cp "${SCRIPT_DIR}/${BIN_NAME}.desktop" \
   "${APPDIR}/usr/share/applications/${BIN_NAME}.desktop"
cp "${SCRIPT_DIR}/${BIN_NAME}.png" \
   "${APPDIR}/usr/share/icons/hicolor/256x256/apps/${BIN_NAME}.png"

# AppRun: the entry point that gets executed when the user runs the AppImage.
# For a single-binary app this is just a thin wrapper that execs the binary.
cat > "${APPDIR}/AppRun" <<'APPRUN'
#!/usr/bin/env bash
HERE="$(dirname -- "$(readlink -f -- "${0}")")"
export PATH="${HERE}/usr/bin:${PATH}"
exec "${HERE}/usr/bin/hello-go" "$@"
APPRUN
chmod +x "${APPDIR}/AppRun"

validate_appdir "$APPDIR"

log_info "Packaging AppImage with appimagetool"
mkdir -p "$OUT_DIR"
# ARCH must be set so appimagetool names the file correctly.
ARCH=x86_64 appimagetool --no-appstream "$APPDIR" "${OUT_DIR}/${APP_NAME}-x86_64.AppImage"

log_ok "Built: ${OUT_DIR}/${APP_NAME}-x86_64.AppImage"
ls -la "${OUT_DIR}/${APP_NAME}-x86_64.AppImage"

log_info "Smoke test"
APPIMAGE_EXTRACT_AND_RUN=1 "${OUT_DIR}/${APP_NAME}-x86_64.AppImage" --version
APPIMAGE_EXTRACT_AND_RUN=1 "${OUT_DIR}/${APP_NAME}-x86_64.AppImage" --name manzolo
