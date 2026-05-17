#!/usr/bin/env bash
# Interactive guided walkthrough.
#
# For each step:
#   1. Prints a short explanation of what the step does.
#   2. Shows the exact command in a boxed "$ ..." line.
#   3. Prompts the user with [Y/n/s/q]:
#         Y / <enter>  run the command
#         n            skip this step
#         s            show the explanation again
#         q            quit the wizard

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"

cd "$REPO_ROOT"

banner() {
    printf '\n%s%s%s\n' "${C_CYAN}${C_BOLD}" "$1" "${C_RESET}"
    printf '%s%s%s\n\n' "${C_DIM}" "$(printf '%.0s-' $(seq 1 ${#1}))" "${C_RESET}"
}

# step "Title" "Multi-line explanation" "shell command to run"
step() {
    local title="$1"
    local explanation="$2"
    local cmd="$3"

    banner "$title"
    printf '%s\n\n' "$explanation"

    while true; do
        printf '%s%s%s\n' "${C_DIM}\$" " ${cmd}${C_RESET}" ""
        printf '%s' "${C_YELLOW}Run this command? [Y/n/s/q]${C_RESET} "
        local reply
        read -r reply || reply="q"
        reply="${reply,,}"
        case "$reply" in
            ""|y|yes)
                printf '\n'
                # shellcheck disable=SC2086
                bash -c "$cmd"
                local rc=$?
                if [[ $rc -ne 0 ]]; then
                    log_error "Command exited with status $rc"
                    if ! confirm "Continue anyway?" n; then
                        log_warn "Wizard aborted."
                        exit "$rc"
                    fi
                fi
                return 0
                ;;
            n|no|skip)
                log_warn "Skipped."
                return 0
                ;;
            s|show)
                printf '\n%s\n\n' "$explanation"
                ;;
            q|quit|exit)
                log_warn "Wizard quit by user."
                exit 0
                ;;
            *)
                printf 'Please answer Y, n, s, or q.\n'
                ;;
        esac
    done
}

clear
cat <<'EOF'
======================================================================
  ManzoloAppImage — interactive wizard

  This walkthrough builds the three example AppImages step by step.
  Each step shows you the command BEFORE running it so you can
  understand what is happening.

  At any prompt you can press:
      Y / <enter>  run the shown command
      n            skip this step
      s            show the explanation again
      q            quit the wizard
======================================================================
EOF
echo
if ! confirm "Ready to start?" y; then
    log_warn "Wizard aborted by user."
    exit 0
fi

# ---------- step 1: prerequisites ------------------------------------------
step "Step 1 / 7 — Check prerequisites" \
"We need Docker installed and the daemon running. The whole build is
performed inside a container, so nothing gets installed on your host.
This command prints the Docker version; if it errors, install Docker
from https://docs.docker.com/engine/install/ and try again." \
"docker --version && docker info --format 'Server: {{.ServerVersion}}'"

# ---------- step 2: build builder image ------------------------------------
step "Step 2 / 7 — Build the builder Docker image" \
"This builds an Ubuntu 22.04 image with every AppImage tool we need:
appimagetool, linuxdeploy, the GTK and Python linuxdeploy plugins,
plus Go, g++/GTK headers, Python, and ImageMagick. The image is tagged
'manzolo-appimage-builder:latest'. First run takes a few minutes; later
runs are cached." \
"docker build -t manzolo-appimage-builder:latest docker/"

# ---------- step 3: build Go example ---------------------------------------
step "Step 3 / 7 — Build the Go CLI AppImage" \
"The simplest possible AppImage: a single static Go binary, no shared
libraries, no runtime. We compile main.go, lay out an AppDir with the
binary + .desktop file + icon, then call appimagetool to pack it." \
"./scripts/build-in-docker.sh 01-go-cli"

# ---------- step 4: inspect the produced AppImage --------------------------
step "Step 4 / 7 — Inspect the produced AppImage" \
"An AppImage is just a SquashFS filesystem with a small ELF runtime
prepended. Passing '--appimage-extract' unpacks it, revealing the
AppDir layout: AppRun (entry point), the .desktop file, the icon, and
usr/bin/<binary>. This is the entire 'magic'." \
"cd out && ./HelloGo-x86_64.AppImage --appimage-extract >/dev/null && ls -la squashfs-root/ && rm -rf squashfs-root && cd .."

# ---------- step 5: run Go AppImage ----------------------------------------
step "Step 5 / 7 — Run the Go AppImage" \
"Now we actually execute it. Because we're potentially inside an
environment without FUSE (e.g. some containers, some CI runners), we
set APPIMAGE_EXTRACT_AND_RUN=1, which tells the runtime to extract the
SquashFS to a temp dir and execute from there." \
"APPIMAGE_EXTRACT_AND_RUN=1 ./out/HelloGo-x86_64.AppImage"

# ---------- step 6: build Python example -----------------------------------
step "Step 6 / 7 — Build the Python GUI AppImage" \
"This example shows the real power of AppImage: bundling an interpreter
+ libraries. linuxdeploy-plugin-python downloads CPython and packages
it inside the AppDir, so the resulting AppImage runs on a target system
that has no Python installed at all." \
"./scripts/build-in-docker.sh 02-python-gui"

# ---------- step 7: build C++ example --------------------------------------
step "Step 7 / 7 — Build the C++ GTK AppImage" \
"The traditional AppImage case: a native binary with .so dependencies
(GTK, GIO, glib, ...). linuxdeploy walks ldd and copies every needed
shared library into AppDir/usr/lib; linuxdeploy-plugin-gtk additionally
bundles GTK icon themes, GIO modules, and the GDK pixbuf loaders so
the GUI looks right on any distro." \
"./scripts/build-in-docker.sh 03-cpp-gtk"

banner "Done!"
cat <<EOF
All three AppImages should now be in ${C_CYAN}out/${C_RESET}:

EOF
ls -la "${REPO_ROOT}/out/" || true
cat <<EOF

Try:  ${C_GREEN}make run-go${C_RESET}      — run the CLI again
      ${C_GREEN}make run-python${C_RESET}  — launch the Python GUI (needs an X server)
      ${C_GREEN}make run-cpp${C_RESET}     — launch the C++ GTK GUI

To start over from scratch:
      ${C_GREEN}make clean${C_RESET}       — remove out/ and AppDirs
      ${C_GREEN}make distclean${C_RESET}   — also remove the Docker image

See README.md for the full guide.
EOF
