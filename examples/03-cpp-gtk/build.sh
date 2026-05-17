#!/usr/bin/env bash
# Build the C++ GTK3 AppImage.
#
# The classic AppImage scenario: a native binary with many .so dependencies
# (GTK, GIO, GLib, Pango, Cairo, libX11, ...). linuxdeploy walks ldd and
# copies every required shared library into AppDir/usr/lib. The GTK plugin
# additionally bundles GIO modules, the GDK pixbuf loaders, and the
# Adwaita icon theme — without these the app would start with a broken
# look and missing icons.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source=../../scripts/common.sh
source "${REPO_ROOT}/scripts/common.sh"

APP_NAME="HelloCpp"
BIN_NAME="hello-cpp"
APPDIR="${SCRIPT_DIR}/AppDir"
OUT_DIR="${REPO_ROOT}/out"

log_info "Cleaning previous build"
rm -rf "$APPDIR" "${SCRIPT_DIR}/build" "${OUT_DIR}/${APP_NAME}-x86_64.AppImage"

log_info "Compiling C++ binary against GTK3"
( cd "$SCRIPT_DIR" && make )

mkdir -p "${APPDIR}/usr/bin" \
         "${APPDIR}/usr/share/applications" \
         "${APPDIR}/usr/share/icons/hicolor/256x256/apps"

log_info "Generating placeholder icon"
ensure_icon "${SCRIPT_DIR}/${BIN_NAME}.png" "C" "#00599C" "#ffffff"

log_info "Placing binary, .desktop and icon"
cp "${SCRIPT_DIR}/build/${BIN_NAME}" "${APPDIR}/usr/bin/${BIN_NAME}"
cp "${SCRIPT_DIR}/${BIN_NAME}.desktop" "${APPDIR}/${BIN_NAME}.desktop"
cp "${SCRIPT_DIR}/${BIN_NAME}.png"     "${APPDIR}/${BIN_NAME}.png"
cp "${SCRIPT_DIR}/${BIN_NAME}.desktop" "${APPDIR}/usr/share/applications/${BIN_NAME}.desktop"
cp "${SCRIPT_DIR}/${BIN_NAME}.png"     "${APPDIR}/usr/share/icons/hicolor/256x256/apps/${BIN_NAME}.png"

log_info "Running linuxdeploy with the GTK plugin"
# DEPLOY_GTK_VERSION tells the gtk plugin which GTK to bundle (3 or 4).
DEPLOY_GTK_VERSION=3 linuxdeploy \
    --appdir "$APPDIR" \
    --executable "${APPDIR}/usr/bin/${BIN_NAME}" \
    --desktop-file "${APPDIR}/${BIN_NAME}.desktop" \
    --icon-file    "${APPDIR}/${BIN_NAME}.png" \
    --plugin gtk

# linuxdeploy-plugin-gtk drops in a custom AppRun that sets GIO_MODULE_DIR,
# GTK_DATA_PREFIX, GDK_PIXBUF_MODULE_FILE, XDG_DATA_DIRS, etc. We keep that
# AppRun verbatim — overriding it would lose those crucial env vars.

validate_appdir "$APPDIR"

log_info "Packing AppImage with appimagetool"
mkdir -p "$OUT_DIR"
ARCH=x86_64 appimagetool --no-appstream "$APPDIR" "${OUT_DIR}/${APP_NAME}-x86_64.AppImage"

log_ok "Built: ${OUT_DIR}/${APP_NAME}-x86_64.AppImage"
ls -la "${OUT_DIR}/${APP_NAME}-x86_64.AppImage"

if command -v xvfb-run >/dev/null && [[ "${SKIP_SMOKE_TEST:-0}" != "1" ]]; then
    log_info "Smoke test under Xvfb (window auto-closes after 1500ms)"
    SMOKE_TEST_MS=1500 xvfb-run -a \
        env APPIMAGE_EXTRACT_AND_RUN=1 \
        "${OUT_DIR}/${APP_NAME}-x86_64.AppImage" \
        && log_ok "GUI launched successfully" \
        || log_warn "Smoke test failed (this can be normal in some CI envs)"
fi
