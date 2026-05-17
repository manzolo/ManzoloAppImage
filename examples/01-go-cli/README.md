# Example 01 — Go CLI

A minimal Go CLI packaged as an AppImage. This is the simplest case: Go produces a single static binary with no shared-library dependencies, so the AppDir holds just the binary, a `.desktop` file, an icon, and an `AppRun` entry point.

## Files

| File              | Role |
|-------------------|------|
| `main.go`         | The Go source (flags: `--name`, `--version`). |
| `go.mod`          | Go module file. |
| `hello-go.desktop`| Desktop entry (Name, Exec, Icon, Categories). |
| `build.sh`        | Builds the binary, lays out the AppDir, and packs with `appimagetool`. |
| `hello-go.png`    | Placeholder icon (generated at build time by ImageMagick). |

## Resulting AppDir layout

```
AppDir/
├── AppRun                                 # entry point (exec usr/bin/hello-go)
├── hello-go.desktop                       # required at root by appimagetool
├── hello-go.png                           # required at root (icon)
└── usr/
    ├── bin/hello-go                       # the static binary
    └── share/
        ├── applications/hello-go.desktop  # XDG-standard copy
        └── icons/hicolor/256x256/apps/hello-go.png
```

## Build

From the repo root:

```
make build-go
```

Output: `out/HelloGo-x86_64.AppImage`.

## Run

```
chmod +x out/HelloGo-x86_64.AppImage
./out/HelloGo-x86_64.AppImage --name manzolo
```

If FUSE is not available (e.g. inside a container):

```
APPIMAGE_EXTRACT_AND_RUN=1 ./out/HelloGo-x86_64.AppImage
```

## Teaching point

A Go-built AppImage is small (~3–4 MB), self-contained, and runs on essentially any Linux x86_64 distro with a glibc newer than the build host's. No `linuxdeploy` was needed because the binary has zero `.so` dependencies (`CGO_ENABLED=0`).
