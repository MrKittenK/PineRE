#!/usr/bin/env python3
import tkinter as tk
from tkinter import ttk, filedialog, messagebox
from pathlib import Path

class TartanBuilder:
    def __init__(self, root):
        self.root = root
        self.root.title("PineRE Tartan v0.01 Builder")
        self.root.geometry("900x650")

        self.device = tk.StringVar()
        self.bootmode = tk.StringVar(value="es")

        nb = ttk.Notebook(root)
        nb.pack(fill="both", expand=True)

        # SD Card
        sd = ttk.Frame(nb)
        nb.add(sd, text="SD Card")
        ttk.Label(sd, text="Target Device").pack(anchor="w", padx=10, pady=5)
        ttk.Entry(sd, textvariable=self.device, width=40).pack(anchor="w", padx=10)
        ttk.Label(sd, text="Example: /dev/sdb").pack(anchor="w", padx=10)

        # Boot
        boot = ttk.Frame(nb)
        nb.add(boot, text="Boot")
        ttk.Label(boot, text="Boot System: extlinux.conf (FROZEN)").pack(anchor="w", padx=10, pady=10)
        ttk.Label(boot, text="R36 Ultra DTB: rk3326-r36ultra.dtb").pack(anchor="w", padx=10)

        # Features
        feat = ttk.Frame(nb)
        nb.add(feat, text="Features")
        for item in [
            "PineRE Boot Test",
            "PineRE Splash",
            "LED Subsystem",
            "Drop To Alpine Shell",
        ]:
            v = tk.BooleanVar(value=True)
            ttk.Checkbutton(feat, text=item, variable=v).pack(anchor="w", padx=10)

        # Boot Modes
        modes = ttk.Frame(nb)
        nb.add(modes, text="Boot Modes")

        ttk.Label(modes, text="Frozen Tartan Architecture").pack(anchor="w", padx=10, pady=10)

        mapping = """
None    -> EmulationStation
L1      -> Shell
R1      -> XFCE
R2      -> Waydroid
SELECT  -> PineRE Boot Manager
"""
        ttk.Label(modes, text=mapping).pack(anchor="w", padx=10)

        # LEDs
        leds = ttk.Frame(nb)
        nb.add(leds, text="LEDs")
        ttk.Label(leds, text="Migrate Claude LED subsystem").pack(anchor="w", padx=10, pady=10)

        # Debug
        debug = ttk.Frame(nb)
        nb.add(debug, text="Debug")
        for item in [
            "Verbose Boot",
            "Framebuffer Test",
            "Drop To Shell",
            "Show PineRE Mode Screen",
        ]:
            v = tk.BooleanVar(value=True)
            ttk.Checkbutton(debug, text=item, variable=v).pack(anchor="w", padx=10)

        # Build
        build = ttk.Frame(nb)
        nb.add(build, text="Build")

        ttk.Button(build, text="Generate extlinux.conf", command=self.make_extlinux).pack(pady=5)
        ttk.Button(build, text="Generate Build Plan", command=self.plan).pack(pady=5)
        ttk.Button(build, text="Run tartan_sdcard_build.sh", command=self.build).pack(pady=5)

        self.log = tk.Text(build, height=20)
        self.log.pack(fill="both", expand=True, padx=10, pady=10)

    def write(self, msg):
        self.log.insert("end", msg + "\n")
        self.log.see("end")

    def make_extlinux(self):
        content = """DEFAULT pinere
TIMEOUT 1

LABEL pinere
    MENU LABEL PineRE Tartan v0.01
    LINUX /Image
    FDT /rk3326-r36ultra.dtb
    APPEND root=/dev/mmcblk0p2 rw rootwait console=ttyS2,1500000n8 bootmode=es
"""
        Path("extlinux.conf").write_text(content)
        self.write("Generated extlinux.conf")

    def plan(self):
        self.write("Build Plan")
        self.write("BOOT / ROOT / EASYROMS")
        self.write("Install Alpine")
        self.write("Install extlinux.conf")
        self.write("Install PineRE Boot Test")
        self.write("Boot -> Splash -> Mode -> Shell")

    def build(self):
        self.write("Execute: ./tartan_sdcard_build.sh " + self.device.get())

root = tk.Tk()
TartanBuilder(root)
root.mainloop()
