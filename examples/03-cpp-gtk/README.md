# Example 03 — C++ GTK3 GUI

A native GTK3 GUI packaged as an AppImage using `linuxdeploy` + `linuxdeploy-plugin-gtk`. This is the *classic* AppImage case: a native binary that links against a chain of shared libraries (GTK, GIO, GLib, Pango, Cairo, libX11, ...).

## What `linuxdeploy-plugin-gtk` does for us

It's not just "copy .so files in". GTK is an unusually environment-sensitive runtime, and getting it to work from an arbitrary mountpoint requires:

| Concern               | What the plugin handles |
|-----------------------|-------------------------|
| ELF dependencies      | Copies every `.so` returned by `ldd` into `AppDir/usr/lib/`. |
| GIO modules           | Copies `gvfs`, `dconf` and related modules to `AppDir/usr/lib/gio/modules/`. |
| GdkPixbuf loaders     | Copies image-loader `.so`s and writes a `loaders.cache`. |
| Icon themes           | Bundles the Adwaita icon theme so symbolic icons render. |
| Gtk settings          | Sets `GTK_DATA_PREFIX`, `XDG_DATA_DIRS`, `GTK_THEME` in the generated AppRun. |
| AppRun                | Writes a custom AppRun that exports the right env vars before exec'ing your binary. |

If you tried to do this by hand you'd reinvent the plugin within a week.

## Build

```
make build-cpp
```

Output: `out/HelloCpp-x86_64.AppImage`.

## Run

```
chmod +x out/HelloCpp-x86_64.AppImage
./out/HelloCpp-x86_64.AppImage
```

Headless smoke test:

```
SMOKE_TEST_MS=2000 xvfb-run -a ./out/HelloCpp-x86_64.AppImage
```

## Teaching point

When your dependency graph is wide and runtime-sensitive (GTK, Qt, …), don't fight it — use the plugin matched to your toolkit (`linuxdeploy-plugin-gtk`, `linuxdeploy-plugin-qt`). Manual `ldd` walking gets ~80% there; the last 20% (icon themes, loaders, gsettings schemas) is what bites you in production.

## Adapting this to your own C/C++ app

1. Replace `src/main.cpp` with your sources; update the `Makefile` (or swap in CMake — `linuxdeploy` cares only about the produced binary).
2. Change `Exec=`/`Icon=`/`Name=` in `hello-cpp.desktop`.
3. If you target GTK4 instead of GTK3, set `DEPLOY_GTK_VERSION=4` in `build.sh` and adjust the `pkg-config` package in the `Makefile` to `gtk4`.
4. For Qt apps, swap the plugin: `--plugin qt` (drop the `DEPLOY_GTK_VERSION` env var).
5. Rebuild: `make build-cpp`.
