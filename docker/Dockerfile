# ManzoloAppImage builder image.
#
# Provides a reproducible Ubuntu 22.04 environment with every tool needed
# to package the three example projects as AppImages:
#   - appimagetool        (final SquashFS + runtime header pack)
#   - linuxdeploy         (AppDir builder, walks ldd, runs plugins)
#   - linuxdeploy plugins (gtk, python, appimage)
#   - language toolchains (Go, Python+venv tooling, g++/GTK3 headers)
#   - ImageMagick         (generate placeholder PNG icons at build time)
#
# Note on FUSE: AppImages normally rely on FUSE to mount their SquashFS at
# runtime, but FUSE is rarely available inside Docker. The build scripts
# always invoke produced AppImages with APPIMAGE_EXTRACT_AND_RUN=1, which
# extracts the SquashFS to a temp dir instead.

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    APPIMAGE_EXTRACT_AND_RUN=1 \
    LANG=C.UTF-8

# ----- Base build tools + runtime deps for all three examples ---------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl wget file git xz-utils \
        build-essential pkg-config make \
        # GTK3 (for the C++ example)
        libgtk-3-dev libgtk-3-0 \
        # Python (for the Python example).
        # python3-tk is the Debian/Ubuntu package that provides Tkinter;
        # without it `import tkinter` fails inside the bundled interpreter.
        python3 python3-pip python3-venv python3-tk \
        tcl tk \
        # GUI smoke-testing in CI
        xvfb \
        # Icon generation
        imagemagick \
        # AppImage runtime helpers (extracted by appimagetool)
        zsync \
        # Misc
        desktop-file-utils sudo \
    && rm -rf /var/lib/apt/lists/*

# ----- Go toolchain ---------------------------------------------------------
# Pin Go so builds are reproducible.
ARG GO_VERSION=1.22.5
RUN curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" \
        -o /tmp/go.tar.gz \
    && tar -C /usr/local -xzf /tmp/go.tar.gz \
    && rm /tmp/go.tar.gz
ENV PATH="/usr/local/go/bin:${PATH}" \
    GOPATH=/tmp/.gocache \
    GOCACHE=/tmp/.gocache/build

# ----- AppImage tooling -----------------------------------------------------
# Pin to known-good "continuous" releases. These are the canonical upstream
# binaries published by AppImageKit / linuxdeploy on GitHub Releases.
ENV TOOLS_DIR=/opt/appimage-tools
RUN mkdir -p "${TOOLS_DIR}" \
    && cd "${TOOLS_DIR}" \
    && curl -fsSL -o appimagetool \
        https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage \
    && curl -fsSL -o linuxdeploy \
        https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage \
    && curl -fsSL -o linuxdeploy-plugin-gtk \
        https://raw.githubusercontent.com/linuxdeploy/linuxdeploy-plugin-gtk/master/linuxdeploy-plugin-gtk.sh \
    && curl -fsSL -o linuxdeploy-plugin-appimage \
        https://github.com/linuxdeploy/linuxdeploy-plugin-appimage/releases/download/continuous/linuxdeploy-plugin-appimage-x86_64.AppImage \
    && curl -fsSL -o linuxdeploy-plugin-python.tar.gz \
        https://github.com/niess/linuxdeploy-plugin-python/archive/refs/heads/master.tar.gz \
    && tar -xzf linuxdeploy-plugin-python.tar.gz \
    && mv linuxdeploy-plugin-python-master linuxdeploy-plugin-python-src \
    && ln -sf "${TOOLS_DIR}/linuxdeploy-plugin-python-src/linuxdeploy-plugin-python.sh" \
              "${TOOLS_DIR}/linuxdeploy-plugin-python" \
    && rm linuxdeploy-plugin-python.tar.gz \
    && chmod +x appimagetool linuxdeploy linuxdeploy-plugin-gtk linuxdeploy-plugin-appimage \
                linuxdeploy-plugin-python-src/linuxdeploy-plugin-python.sh

ENV PATH="${TOOLS_DIR}:${PATH}"

# ImageMagick policy in Ubuntu 22.04 blocks PNG writes by default; relax it
# so the build scripts can generate placeholder icons.
RUN sed -i 's|<policy domain="coder" rights="none" pattern="PNG" />|<policy domain="coder" rights="read\|write" pattern="PNG" />|' \
        /etc/ImageMagick-6/policy.xml || true

# ----- Workspace ------------------------------------------------------------
WORKDIR /work
VOLUME ["/work"]

# Default to a shell; the real entry point is invoked from the host's
# scripts/build-in-docker.sh which mounts the repo and runs the example's
# build.sh script.
CMD ["/bin/bash"]
