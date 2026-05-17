#!/usr/bin/env python3
"""Tkinter demo packaged as an AppImage with a bundled CPython interpreter."""

import os
import sys
import tkinter as tk
from tkinter import ttk


def main() -> int:
    root = tk.Tk()
    root.title("Hello Python (AppImage)")
    root.geometry("420x220")
    root.minsize(320, 160)

    style = ttk.Style(root)
    if "clam" in style.theme_names():
        style.theme_use("clam")

    frame = ttk.Frame(root, padding=24)
    frame.pack(fill=tk.BOTH, expand=True)

    ttk.Label(frame, text="Hello from a bundled Python!", font=("Sans", 14, "bold")).pack(pady=(0, 8))
    ttk.Label(frame, text=f"Python {sys.version.split()[0]}").pack()
    ttk.Label(frame, text=f"Running from: {os.environ.get('APPDIR', '(not an AppImage)')}",
              foreground="#555").pack(pady=(0, 12))

    clicks = tk.IntVar(value=0)
    ttk.Label(frame, textvariable=clicks).pack()

    def on_click() -> None:
        clicks.set(clicks.get() + 1)

    ttk.Button(frame, text="Click me", command=on_click).pack(pady=(0, 4))
    ttk.Button(frame, text="Quit", command=root.destroy).pack()

    # Allow scripted smoke-test: exit after N ms when SMOKE_TEST_MS is set.
    smoke = os.environ.get("SMOKE_TEST_MS")
    if smoke and smoke.isdigit():
        root.after(int(smoke), root.destroy)

    root.mainloop()
    return 0


if __name__ == "__main__":
    sys.exit(main())
