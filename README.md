# ManzoloAppImage — From Idea to AppImage, A to Z

<a href="https://www.buymeacoffee.com/manzolo">
  <img src=".github/blue-button.png" alt="Buy Me A Coffee" width="200">
</a>

A complete, hands-on walkthrough of packaging Linux desktop applications as **AppImages**. Three runnable examples in three different languages (Go, Python, C++), a reproducible Docker build environment, an interactive `make wizard`, and GitHub Actions that build & smoke-test everything on every push.

> **Audience:** developers on Ubuntu (or any Linux) who have an idea — a CLI tool, a GUI app, a service — and want to ship it as a single self-contained file that runs on essentially any modern Linux distro.

---

## Table of contents

1. [What is an AppImage?](#1-what-is-an-appimage)
2. [Anatomy of an AppImage](#2-anatomy-of-an-appimage)
3. [Prerequisites](#3-prerequisites)
4. [Quick start](#4-quick-start)
5. [The build environment (Docker)](#5-the-build-environment-docker)
6. [Tutorial 1 — Go CLI from scratch](#6-tutorial-1--go-cli-from-scratch)
7. [Tutorial 2 — Python GUI with bundled interpreter](#7-tutorial-2--python-gui-with-bundled-interpreter)
8. [Tutorial 3 — C++ GTK with shared-lib deps](#8-tutorial-3--c-gtk-with-shared-lib-deps)
9. [Desktop integration](#9-desktop-integration)
10. [Signing AppImages](#10-signing-appimages)
11. [Distribution & updates](#11-distribution--updates)
12. [CI/CD with GitHub Actions](#12-cicd-with-github-actions)
13. [Troubleshooting](#13-troubleshooting)
14. [From your idea to an AppImage — a checklist](#14-from-your-idea-to-an-appimage--a-checklist)
15. [Further reading](#15-further-reading)

---

## 1. What is an AppImage?

An **AppImage** is a single executable file that contains an entire application plus every dependency it needs to run — interpreter, shared libraries, data files, icons. The user downloads one file, marks it executable, and double-clicks. No installer, no root, no daemon, no store.

Under the hood, an AppImage is a tiny ELF runtime header concatenated with a [SquashFS](https://en.wikipedia.org/wiki/SquashFS) filesystem image. When the user runs it, the runtime mounts the SquashFS (normally via FUSE) and execs an entry point called `AppRun`.

Quick comparison with the other "portable Linux app" formats:

| Format    | Daemon / runtime needed? | Sandbox?         | Installation? | One file? |
|-----------|--------------------------|------------------|---------------|-----------|
| **AppImage** | No                    | No (optional via firejail/bwrap) | No   | **Yes** |
| Flatpak   | Yes (`flatpak`)          | Yes (bubblewrap) | Yes (per app) | No        |
| Snap      | Yes (`snapd`)            | Yes (AppArmor)   | Yes (per app) | No        |
| `.deb`    | dpkg/apt                 | No               | Yes           | No        |

AppImage's superpower is **simplicity**: the `.AppImage` *is* the application. Its trade-off is no sandboxing — the app runs with the user's full privileges. Suitable for trusted desktop apps; not a security boundary.

---

## 2. Anatomy of an AppImage

When you "build an AppImage", you really do two things:

1. Assemble an **AppDir** (an ordinary directory) that contains your app and its dependencies.
2. **Pack** that AppDir into the final `.AppImage` file (SquashFS + runtime header).

Step 2 is mechanical, done by [`appimagetool`](https://github.com/AppImage/appimagetool). Step 1 is where all the work is.

### Minimal AppDir layout

```
MyApp.AppDir/
├── AppRun                          # required: entry point script or binary
├── myapp.desktop                   # required at root: tells the system the name/icon/exec
├── myapp.png                       # required at root: the icon (or *.svg)
└── usr/
    ├── bin/myapp                   # your binary
    ├── lib/                        # bundled .so dependencies (gathered by linuxdeploy)
    └── share/
        ├── applications/myapp.desktop          # XDG-standard copy
        ├── icons/hicolor/256x256/apps/myapp.png
        └── metainfo/myapp.appdata.xml          # optional: AppStream metadata
```

The three pieces that **must** sit at the AppDir root:

- **`AppRun`** — Bash script *or* binary. Receives `argv` and executes your app. For simple apps it's a one-line wrapper; for GTK/Qt apps it exports environment variables first.
- **`*.desktop`** — A [Freedesktop desktop entry](https://specifications.freedesktop.org/desktop-entry-spec/latest/). Required keys: `Name`, `Exec`, `Icon`, `Type=Application`, `Categories`.
- **`*.png` (or `*.svg`)** — The icon, named the same as the `Icon=` value in the desktop file (sans extension).

### The runtime layer

The final `.AppImage` file looks like this, byte-wise:

```
[ ~100 KB ELF runtime ][ SquashFS image of the AppDir ]
```

When run, the runtime:
1. Mounts the SquashFS read-only via FUSE at `/tmp/.mount_XXXXXX`.
2. Sets `$APPDIR` to that mount point.
3. Execs `$APPDIR/AppRun` with the user's argv.

On systems where FUSE isn't available (Docker containers, some CI runners), use:

```bash
APPIMAGE_EXTRACT_AND_RUN=1 ./MyApp.AppImage   # extract to /tmp first, then run
```

Or inspect contents without running:

```bash
./MyApp.AppImage --appimage-extract           # unpacks to ./squashfs-root/
```

---

## 3. Prerequisites

- **Ubuntu 22.04+** (or any modern Linux — Fedora/Arch/Debian all work the same way).
- **Docker** installed and your user in the `docker` group, *or* the patience to type `sudo` a lot.
- **~2 GB** free disk for the builder image + intermediate AppDirs.
- An idea for an app, even if it's just "hello world".

You do **not** need any of the AppImage tools installed on your host — they all live inside the Docker builder image.

---

## 4. Quick start

Two paths.

### Guided (recommended for first-time users)

```
make wizard
```

This walks you through every step — checking Docker, building the builder image, then building, inspecting, and running each example AppImage. For every step, the wizard:

1. Prints a short explanation of what's about to happen.
2. Shows you the **exact command** in a `$ ...` box.
3. Asks `[Y/n/s/q]` before running it.

Use this if you want to *learn*, not just to get a binary.

### Direct

```
make image          # one-time: build the Docker builder image
make build-go       # → out/HelloGo-x86_64.AppImage
make build-python   # → out/HelloPython-x86_64.AppImage
make build-cpp      # → out/HelloCpp-x86_64.AppImage
make build-all      # all three

make run-go         # smoke-test the Go CLI
make clean          # remove out/ and AppDirs (keeps Docker image)
make distclean      # also remove the Docker image — true "start from zero"

make help           # list every target
```

---

## 5. The build environment (Docker)

Everything builds inside the `manzolo-appimage-builder` container. Why Docker?

- **Reproducibility.** Same image, same output, regardless of host distro.
- **No host pollution.** No need to `apt install` AppImage tools, Go, GTK headers, etc.
- **CI parity.** GitHub Actions builds against the same image you use locally.

### What's in the image

`docker/Dockerfile` is fully commented. The short version:

- Base: `ubuntu:22.04` (glibc 2.35 — old enough to be widely compatible).
- AppImage tooling: `appimagetool`, `linuxdeploy`, `linuxdeploy-plugin-gtk`, `linuxdeploy-plugin-python`, `linuxdeploy-plugin-appimage`.
- Toolchains: Go 1.22, Python 3 + venv tools, `g++`, GTK3 development headers.
- Testing: `Xvfb` for headless GUI smoke tests.
- Misc: `ImageMagick` for generating placeholder icons at build time.

### Why Ubuntu 22.04?

AppImages are *forward-compatible*: a binary built against glibc 2.35 runs on systems with glibc ≥ 2.35, but not on older ones. If you build on Ubuntu 24.04 (glibc 2.39), users on Ubuntu 22.04 will see "GLIBC_2.39 not found". **Build on the oldest distro you want to support.** Ubuntu 22.04 is a reasonable default for 2026-era support.

### The FUSE caveat

AppImages mount themselves via FUSE at runtime. Inside Docker, `/dev/fuse` typically isn't available and even when it is, you'd need `--privileged`. Workarounds:

- Set `APPIMAGE_EXTRACT_AND_RUN=1` in the environment — the runtime extracts the SquashFS to `/tmp` instead of mounting. Our Docker image and build scripts do this by default.
- Or: install `libfuse2` (AppImage's runtime uses FUSE2, **not** FUSE3) and run Docker with `--device /dev/fuse --cap-add SYS_ADMIN`.

The first option is simpler and the only one we use here.

---

## 6. Tutorial 1 — Go CLI from scratch

Goal: package a "hello world" Go CLI as an AppImage. See [`examples/01-go-cli/`](examples/01-go-cli/).

### Step 1 — Write the program

```go
// main.go
package main

import (
    "flag"
    "fmt"
)

func main() {
    name := flag.String("name", "world", "name to greet")
    flag.Parse()
    fmt.Printf("Hello, %s!\n", *name)
}
```

### Step 2 — Compile a static binary

`CGO_ENABLED=0` is the key flag — it produces a binary with **no shared library dependencies**, so the AppImage doesn't need any bundled `.so` files.

```bash
CGO_ENABLED=0 go build -trimpath -ldflags='-s -w' -o AppDir/usr/bin/hello-go .
```

### Step 3 — Write a `.desktop` file

```ini
[Desktop Entry]
Type=Application
Name=Hello Go
Exec=hello-go
Icon=hello-go
Categories=Utility;
Terminal=true
```

Save as `AppDir/hello-go.desktop` (and copy a duplicate to `AppDir/usr/share/applications/`).

### Step 4 — Provide an icon

A 256×256 PNG at `AppDir/hello-go.png`. We auto-generate one with ImageMagick:

```bash
convert -size 256x256 xc:'#00ADD8' \
    -fill white -gravity center -font DejaVu-Sans-Bold -pointsize 180 \
    -annotate +0+0 'G' AppDir/hello-go.png
```

### Step 5 — Write `AppRun`

```bash
#!/usr/bin/env bash
HERE="$(dirname -- "$(readlink -f -- "${0}")")"
exec "${HERE}/usr/bin/hello-go" "$@"
```

`chmod +x AppDir/AppRun`. That's it — for a static binary with no deps, no `linuxdeploy` invocation is needed.

### Step 6 — Pack

```bash
ARCH=x86_64 appimagetool --no-appstream AppDir HelloGo-x86_64.AppImage
```

You now have a ~4 MB self-contained `.AppImage` that runs on virtually any Linux x86_64.

```bash
chmod +x HelloGo-x86_64.AppImage
./HelloGo-x86_64.AppImage --name manzolo
# → Hello, manzolo! ...
```

All of this is automated by [`examples/01-go-cli/build.sh`](examples/01-go-cli/build.sh).

---

## 7. Tutorial 2 — Python GUI with bundled interpreter

Goal: package a Tkinter GUI as an AppImage that runs **even on systems with no Python installed**. See [`examples/02-python-gui/`](examples/02-python-gui/).

The hard part isn't the GUI code — it's deciding what to bundle.

### What you need to bundle for Python

1. **The interpreter** itself (`/usr/bin/python3.X` → `AppDir/usr/bin/python3`).
2. **The standard library** (`/usr/lib/python3.X/` → `AppDir/usr/lib/python3.X/`).
3. **The C extension modules** that are part of the stdlib but compiled separately (`/usr/lib/python3.X/lib-dynload/*.so`).
4. **The shared libraries** that Python and its extensions link against (`libpython3.X.so.1.0`, `libssl`, `libcrypto`, `libz`, `libtcl`, `libtk`, …). These come from `ldd` and are gathered by `linuxdeploy`.
5. **Data files** for libraries that look up resources at runtime. The classic example is Tcl/Tk — `tkinter` won't initialize without `init.tcl`, which lives in `/usr/share/tcltk/`.
6. **Your application code** (`app.py` → `AppDir/usr/src/app.py`).
7. **Third-party dependencies** if any (`pip install --target AppDir/usr/lib/python3.X/site-packages -r requirements.txt`).

### The AppRun magic

The `AppRun` for a Python AppImage is more involved than for Go because Python looks at several environment variables to find its stdlib:

```bash
#!/usr/bin/env bash
HERE="$(dirname -- "$(readlink -f -- "${0}")")"
export APPDIR="$HERE"
export PYTHONHOME="$HERE/usr"
export PYTHONPATH="$HERE/usr/lib/python3.10:$HERE/usr/lib/python3.10/site-packages:$HERE/usr/src"
export LD_LIBRARY_PATH="$HERE/usr/lib:${LD_LIBRARY_PATH:-}"
export TCL_LIBRARY="$HERE/usr/share/tcltk/tcl8.6"
export TK_LIBRARY="$HERE/usr/share/tcltk/tk8.6"
exec "$HERE/usr/bin/python3" "$HERE/usr/src/app.py" "$@"
```

The build script ([`examples/02-python-gui/build.sh`](examples/02-python-gui/build.sh)) automates every step. To use it for your own app:

1. Replace `app.py` with your code.
2. Add deps to `requirements.txt`.
3. Update `hello-python.desktop`.
4. `make build-python`.

---

## 8. Tutorial 3 — C++ GTK with shared-lib deps

Goal: package a native GTK3 GUI as an AppImage. See [`examples/03-cpp-gtk/`](examples/03-cpp-gtk/).

This is the *original* AppImage use case: a native binary linking against a chain of shared libraries.

### Why it's harder than it looks

A naive "`ldd` your binary and copy the libs" approach works for a one-off, but production GTK apps need much more:

- **GIO modules** — TLS support, GVFS, ...
- **GdkPixbuf loaders** — PNG, JPEG, SVG decoders are separate `.so`s.
- **Icon themes** — without Adwaita bundled, symbolic icons render as broken squares.
- **GSettings schemas** — needed for any app that uses GSettings.
- **Locale/translation files** if your app is i18n'd.

That's what [`linuxdeploy-plugin-gtk`](https://github.com/linuxdeploy/linuxdeploy-plugin-gtk) is for. It does all of the above *and* writes a custom `AppRun` that sets the right env vars (`GTK_DATA_PREFIX`, `GIO_MODULE_DIR`, `GDK_PIXBUF_MODULE_FILE`, `XDG_DATA_DIRS`).

### The build, in one command

```bash
DEPLOY_GTK_VERSION=3 linuxdeploy \
    --appdir AppDir \
    --executable AppDir/usr/bin/hello-cpp \
    --desktop-file AppDir/hello-cpp.desktop \
    --icon-file    AppDir/hello-cpp.png \
    --plugin gtk

ARCH=x86_64 appimagetool --no-appstream AppDir HelloCpp-x86_64.AppImage
```

The full build script ([`examples/03-cpp-gtk/build.sh`](examples/03-cpp-gtk/build.sh)) wraps this with cleanup, logging, and a headless smoke test.

### For Qt apps

Swap `--plugin gtk` for `--plugin qt`, and replace the GTK headers with `qt6-base-dev` (or 5) in the Dockerfile. The rest is identical.

---

## 9. Desktop integration

To make your AppImage feel like a real installed app, the `.desktop` file matters more than people realise. Useful keys beyond the basics:

| Key                | What it does |
|--------------------|--------------|
| `Categories=`      | Where the launcher menu groups it. See the [registered categories](https://specifications.freedesktop.org/menu-spec/latest/apa.html). |
| `MimeType=`        | File types your app can open. E.g. `MimeType=text/x-markdown;` makes you a Markdown-handler candidate. |
| `Keywords=`        | Search keywords in launchers. |
| `StartupWMClass=`  | Lets the launcher tie running windows back to your icon (Wayland gets this from the window itself). |
| `Actions=`         | Right-click menu entries on the launcher icon (e.g. "New private window"). |

### AppStream metadata

For inclusion in distro app stores and for richer launcher info, ship an AppStream `*.metainfo.xml` at `AppDir/usr/share/metainfo/`. The format is documented at [freedesktop.org/software/appstream](https://www.freedesktop.org/software/appstream/docs/). We pass `--no-appstream` to `appimagetool` in the examples to avoid the warning, but for a real app you should provide one.

### Integration helpers on the user's side

End users typically install [AppImageLauncher](https://github.com/TheAssassin/AppImageLauncher) or [Gear Lever](https://flathub.org/apps/it.mijorus.gearlever) so their downloaded `.AppImage` files automatically appear in the application menu and update themselves. As the developer you don't have to do anything special — these tools read your `.desktop` file from the AppImage.

---

## 10. Signing AppImages

Signed AppImages let users verify they're getting an authentic binary from you. The signature is embedded inside the AppImage itself (not a separate `.sig` file).

### Generate a signing key (one time)

```bash
gpg --quick-generate-key 'Manzolo <manzolo@libero.it>' rsa4096 sign 2y
```

### Sign at build time

```bash
appimagetool --sign --sign-key <KEY-ID> AppDir MyApp-x86_64.AppImage
```

The signature is appended to the ELF runtime header. To verify:

```bash
./MyApp-x86_64.AppImage --appimage-signature   # prints the signature
./MyApp-x86_64.AppImage --appimage-extract _sig
```

### Distributing your public key

Publish your fingerprint somewhere users will trust (your website, your README on GitHub) and tell them to import:

```bash
gpg --recv-keys <FINGERPRINT>
```

> Note: AppImage signing today only protects against tampering after publication. It does **not** chain to any system trust store. Combined with HTTPS distribution and reproducible builds it's a good story; on its own it's a step up from nothing.

---

## 11. Distribution & updates

### Where to publish

- **GitHub Releases** — by far the most common. Attach your `.AppImage` to a tag-based release. Our [`release.yml`](.github/workflows/release.yml) workflow does this automatically on `v*` tags.
- **[AppImageHub](https://appimage.github.io/apps/)** — community catalog. Submit a PR with metadata; gets your app indexed and discoverable.
- **Your own website** — just an HTTPS download link works.

### Update support (`zsync`)

AppImages can update themselves *in-place* by reading a small metadata block embedded in the file and then fetching only the changed SquashFS blocks. This requires:

1. Adding update info when building:
   ```bash
   appimagetool -u 'gh-releases-zsync|manzolo|ManzoloAppImage|latest|HelloGo-*x86_64.AppImage.zsync' AppDir
   ```
2. Publishing the auto-generated `.zsync` file alongside each release.
3. Users running [AppImageUpdate](https://github.com/AppImageCommunity/AppImageUpdate) (built into AppImageLauncher / Gear Lever).

Then `appimageupdatetool MyApp.AppImage` fetches only the delta — usually a few MB even for large apps.

---

## 12. CI/CD with GitHub Actions

The repo ships four workflows under [`.github/workflows/`](.github/workflows/):

| Workflow              | Trigger                       | What it does |
|-----------------------|-------------------------------|--------------|
| `build-go.yml`        | Push / PR touching Go example | Build + smoke-test the Go AppImage, upload as artifact. |
| `build-python.yml`    | Push / PR touching Python     | Same, but smoke-tests the GUI under `Xvfb`. |
| `build-cpp.yml`       | Push / PR touching C++        | Same as Python. |
| `release.yml`         | Tag push `v*`                 | Runs all three builds, then publishes their AppImages to a GitHub Release. |

All three build workflows:

1. Use `docker/build-push-action` with `cache-from: type=gha` so the builder image is cached between runs (the first build is ~5 min; subsequent ones ~30 s).
2. Run the *same* `make build-*` target a developer uses locally — no CI-specific build path.
3. Upload the produced `.AppImage` as a workflow artifact so reviewers can download and try it before merging.

### Releasing

```bash
git tag v0.1.0
git push origin v0.1.0
```

`release.yml` fires, builds all three examples, attaches them to a new GitHub Release, and auto-generates release notes from PR titles.

---

## 13. Troubleshooting

**`fuse: failed to open /dev/fuse: Permission denied`**
You're inside Docker or a container. Use `APPIMAGE_EXTRACT_AND_RUN=1`. If you must use FUSE, run the container with `--device /dev/fuse --cap-add SYS_ADMIN`. Also note AppImage uses **FUSE2** — on systems shipping only FUSE3, install `libfuse2`.

**`/lib/x86_64-linux-gnu/libc.so.6: version 'GLIBC_2.X' not found`**
The AppImage was built against a newer glibc than the target system has. Rebuild on an older base distro (e.g. Ubuntu 22.04 instead of 24.04).

**`Gtk-WARNING **: cannot open display`**
A GUI AppImage running headless. Use `Xvfb`: `xvfb-run -a ./MyApp.AppImage`.

**`Error initializing GObject types: Library "libgtk-3.so.0" not found` (or similar)**
linuxdeploy didn't pick up a transitive dep. Pass that library explicitly: `linuxdeploy ... --library /path/to/missing.so`.

**Tkinter: `_tkinter.TclError: Can't find a usable init.tcl`**
You bundled `_tkinter.so` but not the Tcl/Tk *data files*. Copy `/usr/share/tcltk/` into `AppDir/usr/share/` and export `TCL_LIBRARY` + `TK_LIBRARY` in your `AppRun`.

**Icon doesn't appear in menus after integration**
Make sure: (1) `.desktop` and `.png` both at the AppDir root with matching basenames, (2) `Icon=` in the desktop file doesn't include a path or extension, (3) the file is also at `AppDir/usr/share/icons/hicolor/256x256/apps/<name>.png`.

**`appimagetool: command not found`**
You're running the build outside Docker. Either run `make build-*` (which uses the container) or install the tools on your host from the [AppImageKit releases](https://github.com/AppImage/appimagetool/releases).

**Build hangs forever on `linuxdeploy-plugin-gtk`**
The plugin clones Adwaita icon sources at runtime; on slow networks this stalls. Solution: pre-populate `$HOME/.cache/linuxdeploy-plugin-gtk/` in your Docker image, or use `DEPLOY_GTK_VERSION=3` and pin a known-good plugin commit.

**`make wizard` shows "command not found"**
Check `docker --version` succeeds. The wizard's first step verifies this; if it fails, install Docker from [docs.docker.com](https://docs.docker.com/engine/install/).

---

## 14. From your idea to an AppImage — a checklist

Going from "I have an idea" to "I have a `.AppImage` on a GitHub Release":

- [ ] **Decide what to bundle.** Static binary? Then nothing else. Interpreter (Python, Node)? Bundle it + its stdlib. Native GUI? Use `linuxdeploy` + the toolkit plugin.
- [ ] **Write the app.** Test on your host first.
- [ ] **Author the `.desktop` file.** Pick a stable `Exec=` name (will be the binary in `usr/bin/`) and `Icon=` (will be the icon basename).
- [ ] **Provide an icon** (256×256 PNG, transparent background, simple silhouette).
- [ ] **Pick a build distro old enough** to cover your target glibc.
- [ ] **Write an `AppRun`** — wrapper script that execs your binary, exporting any env vars it needs.
- [ ] **Build the AppDir** — by hand for static binaries, with `linuxdeploy` for native apps, manually + plugin for interpreters.
- [ ] **Pack** with `appimagetool`.
- [ ] **Smoke test** — extract-and-run mode in your CI, real install on a clean VM before publishing.
- [ ] **Sign** with GPG if you publish widely.
- [ ] **Add update info** (`-u gh-releases-zsync|...`) if you'll publish multiple versions.
- [ ] **Publish** to a GitHub Release (or your own site).
- [ ] **Hook up CI** so this happens on every tag push.

---

## 15. Further reading

- **Official AppImage docs:** [docs.appimage.org](https://docs.appimage.org/)
- **`appimagetool`:** [github.com/AppImage/appimagetool](https://github.com/AppImage/appimagetool)
- **`linuxdeploy`:** [github.com/linuxdeploy/linuxdeploy](https://github.com/linuxdeploy/linuxdeploy)
- **`linuxdeploy-plugin-gtk`:** [github.com/linuxdeploy/linuxdeploy-plugin-gtk](https://github.com/linuxdeploy/linuxdeploy-plugin-gtk)
- **`linuxdeploy-plugin-python`:** [github.com/niess/linuxdeploy-plugin-python](https://github.com/niess/linuxdeploy-plugin-python)
- **`python-appimage`:** [github.com/niess/python-appimage](https://github.com/niess/python-appimage) — alternative for pure-Python apps.
- **AppImageHub:** [appimage.github.io](https://appimage.github.io/)
- **AppImageLauncher:** [github.com/TheAssassin/AppImageLauncher](https://github.com/TheAssassin/AppImageLauncher)
- **Desktop entry spec:** [specifications.freedesktop.org/desktop-entry-spec](https://specifications.freedesktop.org/desktop-entry-spec/latest/)
- **AppStream metainfo:** [freedesktop.org/software/appstream](https://www.freedesktop.org/software/appstream/docs/)

---

## License

MIT — see [`LICENSE`](LICENSE). The example code, scripts, Dockerfile, and this README are all yours to copy, modify, and use as a starting point for your own AppImage projects.
