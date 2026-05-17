# Example 02 — Python Tkinter GUI

A Tkinter window packaged as an AppImage with a **bundled CPython interpreter**, so it runs on any glibc-compatible Linux even if Python isn't installed on the target system.

## What gets bundled

```
AppDir/
├── AppRun                              # sets PYTHONHOME, TCL_LIBRARY, etc., execs python3
├── hello-python.desktop
├── hello-python.png
└── usr/
    ├── bin/python3                     # the bundled interpreter
    ├── lib/
    │   ├── python3.10/                 # the full stdlib
    │   │   └── lib-dynload/_tkinter*.so
    │   ├── libpython3.10.so.1.0        # gathered by linuxdeploy
    │   ├── libtcl8.6.so                # tcl runtime (tkinter needs it)
    │   ├── libtk8.6.so
    │   ├── libssl.so.3, libz.so.1, ...
    │   └── ...
    ├── share/
    │   ├── tcltk/                      # tcl/tk *data* files (not just libs)
    │   ├── applications/hello-python.desktop
    │   └── icons/hicolor/256x256/apps/hello-python.png
    └── src/app.py                      # the application source
```

## Build

```
make build-python
```

Output: `out/HelloPython-x86_64.AppImage`.

## Run

```
chmod +x out/HelloPython-x86_64.AppImage
./out/HelloPython-x86_64.AppImage
```

In a headless environment, you can smoke-test under `Xvfb`:

```
SMOKE_TEST_MS=2000 xvfb-run -a ./out/HelloPython-x86_64.AppImage
```

## Teaching points

1. **AppImages can carry an interpreter.** The host system needs no Python.
2. **A stdlib is not the same as a runtime.** Pure-Python stdlib files (`/usr/lib/python3.X/`) and the binary extension modules (`/usr/lib/python3.X/lib-dynload/*.so`) both need to be present, and the `.so` files in turn have their own library dependencies that `ldd` reveals.
3. **Some libraries need data files, not just `.so`.** Tkinter is the classic case — Tcl/Tk look up scripts at runtime under `TCL_LIBRARY` / `TK_LIBRARY`. Bundle them or your AppImage will fail with "can't find init.tcl".
4. **Third-party deps?** Add them to `requirements.txt`. The build script `pip install`s them into `AppDir/usr/lib/python3.X/site-packages/`.

## Adapting this to your own Python app

1. Replace `app.py` with your code (or a `src/` package — set `PYTHONPATH` accordingly in `AppRun`).
2. Add your dependencies to `requirements.txt`.
3. Update the `.desktop` `Name`, `Comment`, `Categories`, and the icon.
4. Rebuild: `make build-python`.
