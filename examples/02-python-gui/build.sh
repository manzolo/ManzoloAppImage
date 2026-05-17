#!/usr/bin/env bash
# Build the Python GUI AppImage.
#
# Unlike the Go example, Python needs an interpreter + its standard library
# at runtime. The goal here is to produce an AppImage that runs on a target
# system *without any system Python installed at all*.
#
# Strategy:
#   1. Copy the build-host Python interpreter into AppDir/usr/bin.
#   2. Copy the matching Python standard library into AppDir/usr/lib.
#   3. Use linuxdeploy to walk ldd and gather every shared lib python3
#      and its extension modules link against (libpython, libssl, libz,
#      libtcl, libtk, ...).
#   4. Copy the Tcl/Tk data files (Tkinter needs them on disk).
#   5. Write an AppRun that sets PYTHONHOME, TCL_LIBRARY, TK_LIBRARY
#      and execs the bundled python on app.py.
#   6. Pack with appimagetool.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source=../../scripts/common.sh
source "${REPO_ROOT}/scripts/common.sh"

APP_NAME="HelloPython"
BIN_NAME="hello-python"
APPDIR="${SCRIPT_DIR}/AppDir"
OUT_DIR="${REPO_ROOT}/out"

# ---- Discover host Python details -----------------------------------------
PYTHON_BIN="${PYTHON_BIN:-$(command -v python3)}"
[[ -x "$PYTHON_BIN" ]] || { log_error "python3 not found"; exit 1; }

PYVER_FULL="$("$PYTHON_BIN" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
PYDIR="python${PYVER_FULL}"              # e.g. python3.10
PYSTDLIB_SRC="/usr/lib/${PYDIR}"
[[ -d "$PYSTDLIB_SRC" ]] || { log_error "Python stdlib not at $PYSTDLIB_SRC"; exit 1; }

# Detect Tcl/Tk version dirs (used at runtime by tkinter).
TCLTK_DATA_SRC="/usr/share/tcltk"

log_info "Bundling Python ${PYVER_FULL} from ${PYTHON_BIN}"
log_info "Cleaning previous build"
rm -rf "$APPDIR" "${OUT_DIR}/${APP_NAME}-x86_64.AppImage"

mkdir -p "${APPDIR}/usr/bin" \
         "${APPDIR}/usr/lib" \
         "${APPDIR}/usr/src" \
         "${APPDIR}/usr/share/applications" \
         "${APPDIR}/usr/share/icons/hicolor/256x256/apps"

# ---- 1. Interpreter -------------------------------------------------------
log_info "Step 1/7: copying Python interpreter"
cp "$PYTHON_BIN" "${APPDIR}/usr/bin/python3"
chmod +x "${APPDIR}/usr/bin/python3"

# ---- 2. Standard library --------------------------------------------------
log_info "Step 2/7: copying Python standard library"
cp -a "$PYSTDLIB_SRC" "${APPDIR}/usr/lib/${PYDIR}"
# Trim caches and tests to keep the AppImage small.
find "${APPDIR}/usr/lib/${PYDIR}" -type d -name __pycache__ -prune -exec rm -rf {} +
find "${APPDIR}/usr/lib/${PYDIR}" -type d -name test -prune -exec rm -rf {} + 2>/dev/null || true

# ---- 3. Generate icon -----------------------------------------------------
log_info "Step 3/7: generating placeholder icon"
ensure_icon "${SCRIPT_DIR}/${BIN_NAME}.png" "P" "#3776AB" "#FFD43B"

# ---- 4. Lay out .desktop + icon at AppDir root + XDG paths ----------------
log_info "Step 4/7: placing .desktop + icon"
cp "${SCRIPT_DIR}/${BIN_NAME}.desktop" "${APPDIR}/${BIN_NAME}.desktop"
cp "${SCRIPT_DIR}/${BIN_NAME}.png"     "${APPDIR}/${BIN_NAME}.png"
cp "${SCRIPT_DIR}/${BIN_NAME}.desktop" "${APPDIR}/usr/share/applications/${BIN_NAME}.desktop"
cp "${SCRIPT_DIR}/${BIN_NAME}.png"     "${APPDIR}/usr/share/icons/hicolor/256x256/apps/${BIN_NAME}.png"

# ---- 5. Application source ------------------------------------------------
log_info "Step 5/7: bundling app source"
cp "${SCRIPT_DIR}/app.py" "${APPDIR}/usr/src/app.py"

# Optional dependencies via pip (if requirements.txt has non-comment lines).
if grep -Eq '^[^#[:space:]]' "${SCRIPT_DIR}/requirements.txt"; then
    log_info "       installing requirements.txt into AppDir/usr/lib/${PYDIR}/site-packages"
    "$PYTHON_BIN" -m pip install \
        --no-cache-dir \
        --target "${APPDIR}/usr/lib/${PYDIR}/site-packages" \
        -r "${SCRIPT_DIR}/requirements.txt"
fi

# ---- 6. Wrapper script + linuxdeploy gathers .so dependencies -------------
# The .desktop file has Exec=hello-python, so linuxdeploy expects an
# executable with that name inside the AppDir. We provide one as a tiny
# bash wrapper that sets up PYTHONHOME / TCL_LIBRARY / TK_LIBRARY and execs
# the bundled interpreter on our app.py. linuxdeploy will then auto-create
# the AppDir/AppRun symlink pointing at this wrapper.
log_info "Step 6/7: writing wrapper + gathering shared-library deps with linuxdeploy"
cat > "${APPDIR}/usr/bin/${BIN_NAME}" <<EOF
#!/usr/bin/env bash
# Wrapper executed by AppRun (symlinked here by linuxdeploy).
HERE="\$(dirname -- "\$(readlink -f -- "\${0}")")"
APPDIR_ROOT="\$(dirname -- "\$(dirname -- "\$HERE")")"
export APPDIR="\$APPDIR_ROOT"
export PYTHONHOME="\$APPDIR/usr"
export PYTHONPATH="\$APPDIR/usr/lib/${PYDIR}:\$APPDIR/usr/lib/${PYDIR}/site-packages:\$APPDIR/usr/src"
export PYTHONDONTWRITEBYTECODE=1
export LD_LIBRARY_PATH="\$APPDIR/usr/lib:\${LD_LIBRARY_PATH:-}"
if [[ -d "\$APPDIR/usr/share/tcltk/tcl8.6" ]]; then
    export TCL_LIBRARY="\$APPDIR/usr/share/tcltk/tcl8.6"
fi
if [[ -d "\$APPDIR/usr/share/tcltk/tk8.6" ]]; then
    export TK_LIBRARY="\$APPDIR/usr/share/tcltk/tk8.6"
fi
exec "\$APPDIR/usr/bin/python3" "\$APPDIR/usr/src/app.py" "\$@"
EOF
chmod +x "${APPDIR}/usr/bin/${BIN_NAME}"

# linuxdeploy needs a .desktop and an icon; we already placed them at the root.
# --executable=python3 makes linuxdeploy walk python3's ldd output.
linuxdeploy \
    --appdir "$APPDIR" \
    --executable "${APPDIR}/usr/bin/python3" \
    --desktop-file "${APPDIR}/${BIN_NAME}.desktop" \
    --icon-file    "${APPDIR}/${BIN_NAME}.png"

# Tcl/Tk extension modules of CPython are compiled .so files inside lib-dynload;
# their library deps (libtcl, libtk, libX11, libfontconfig, ...) are picked up
# by linuxdeploy via the python3 RPATH walk, but the Tcl/Tk *data files* are
# not — copy them manually.
if [[ -d "$TCLTK_DATA_SRC" ]]; then
    log_info "       copying Tcl/Tk runtime data (needed by tkinter)"
    mkdir -p "${APPDIR}/usr/share/tcltk"
    cp -a "$TCLTK_DATA_SRC"/. "${APPDIR}/usr/share/tcltk/"
fi

# On Debian/Ubuntu, python3-tk installs the _tkinter C extension into
# /usr/lib/python3/dist-packages/ (NOT into the stdlib's lib-dynload/).
# Copy it into the bundled stdlib so `import tkinter` succeeds at runtime.
TKINTER_SO_SYS="$(find /usr/lib/python3/dist-packages -maxdepth 1 -name '_tkinter*.so' 2>/dev/null | head -n1 || true)"
if [[ -n "$TKINTER_SO_SYS" ]]; then
    log_info "       copying _tkinter extension into lib-dynload"
    cp "$TKINTER_SO_SYS" "${APPDIR}/usr/lib/${PYDIR}/lib-dynload/"
fi

# Run linuxdeploy over the bundled tkinter .so so its libs (libtk, libtcl,
# libX11, libxcb, libfontconfig) get gathered into AppDir/usr/lib.
TKINTER_SO="$(find "${APPDIR}/usr/lib/${PYDIR}/lib-dynload" -name '_tkinter*.so' | head -n1 || true)"
if [[ -n "$TKINTER_SO" ]]; then
    log_info "       gathering tkinter shared-lib deps"
    linuxdeploy --appdir "$APPDIR" --executable "$TKINTER_SO" \
        --desktop-file "${APPDIR}/${BIN_NAME}.desktop" \
        --icon-file    "${APPDIR}/${BIN_NAME}.png" || true
else
    log_warn "       _tkinter*.so not found in AppDir — tkinter import will fail at runtime"
fi

# ---- 7. Pack with appimagetool --------------------------------------------
# linuxdeploy already created AppDir/AppRun as a symlink to usr/bin/hello-python.
log_info "Step 7/7: packing AppImage with appimagetool"

validate_appdir "$APPDIR"

mkdir -p "$OUT_DIR"
ARCH=x86_64 appimagetool --no-appstream "$APPDIR" "${OUT_DIR}/${APP_NAME}-x86_64.AppImage"

log_ok "Built: ${OUT_DIR}/${APP_NAME}-x86_64.AppImage"
ls -la "${OUT_DIR}/${APP_NAME}-x86_64.AppImage"

# ---- Smoke test under Xvfb (optional) -------------------------------------
if command -v xvfb-run >/dev/null && [[ "${SKIP_SMOKE_TEST:-0}" != "1" ]]; then
    log_info "Smoke test under Xvfb (window auto-closes after 1500ms)"
    SMOKE_TEST_MS=1500 xvfb-run -a \
        env APPIMAGE_EXTRACT_AND_RUN=1 \
        "${OUT_DIR}/${APP_NAME}-x86_64.AppImage" \
        && log_ok "GUI launched successfully" \
        || log_warn "Smoke test failed (this can be normal in some CI envs)"
fi
