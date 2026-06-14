#!/usr/bin/env python3
import tkinter as tk
from tkinter import ttk, messagebox
import subprocess, threading, sys, math

class PineREInstaller(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("PineRE // Retro-Edge Controller")
        self.geometry("1300x900")
        self.configure(bg="#1A1A1C")
        self.stats = {"INFO": 0, "WARN": 0, "ERROR": 0, "FATAL": 0}
        self.stats_vars = {k: tk.StringVar(value=f"{k}: 0") for k in self.stats}

        # Sidebar
        self.nav = tk.Frame(self, bg="#2D2D35", width=350); self.nav.pack(side="left", fill="y")
        tk.Label(self.nav, text="PineRE", fg="#67308F", bg="#2D2D35", font=("Arial", 32, "bold")).pack(pady=20)
        
        self.device_var = tk.StringVar()
        self.drive_menu = ttk.Combobox(self.nav, textvariable=self.device_var, state="readonly", width=40); self.drive_menu.pack(pady=5)
        tk.Button(self.nav, text="↻ Refresh Drives", command=self.refresh, bg="#4A4A55", fg="white").pack(pady=10)
        
        # Phases
        self.phases = { "Partition Drive": tk.BooleanVar(value=True), "Extract RootFS": tk.BooleanVar(value=True), "Install Packages": tk.BooleanVar(value=True) }
        for name, var in self.phases.items():
            tk.Checkbutton(self.nav, text=name, variable=var, bg="#2D2D35", fg="#EEE").pack(anchor="w", padx=20)

        # Spinner
        self.canvas = tk.Canvas(self.nav, width=120, height=120, bg="#2D2D35", highlightthickness=0); self.canvas.pack(pady=20)
        self.arc = self.canvas.create_arc(10, 10, 110, 110, start=90, extent=0, outline="green", width=8, style="arc")
        self.arm = self.canvas.create_line(60, 60, 60, 20, fill="white", width=3)
        self.pct = tk.StringVar(value="0%"); tk.Label(self.nav, textvariable=self.pct, fg="white", bg="#2D2D35", font=("Arial", 16)).pack()

        # Debug & Start
        tk.Button(self.nav, text="START INSTALL", command=self.start, bg="#67308F", fg="white", font=("Arial", 12, "bold")).pack(pady=20)
        self.debug_panel = tk.Frame(self.nav, bg="#2D2D35")
        tk.Checkbutton(self.nav, text="Toggle Debug Mode", command=self.toggle_debug, bg="#2D2D35", fg="white").pack(pady=5)
        for k in self.stats: tk.Label(self.debug_panel, textvariable=self.stats_vars[k], fg="#F9C613", bg="#2D2D35").pack()

        self.log_text = tk.Text(self, bg="#000", fg="#0F0", font=("Consolas", 10)); self.log_text.pack(expand=True, fill="both", padx=10, pady=10)
        self.refresh()

    def toggle_debug(self):
        if self.debug_panel.winfo_ismapped(): self.debug_panel.pack_forget()
        else: self.debug_panel.pack(fill="x")

    def refresh(self):
        try:
            o = subprocess.check_output("lsblk -n -o NAME,SIZE,LABEL -p -e 7 -d", shell=True).decode()
            self.drive_menu['values'] = [l.strip() for l in o.splitlines()]
        except: pass

    def start(self):
        if not self.device_var.get(): return
        threading.Thread(target=self.execute, args=(self.device_var.get().split()[0],), daemon=True).start()

    def execute(self, dev):
        env = {**os.environ, "TARGET_DEV": dev, "SELECTED_PHASES": ",".join([n for n, v in self.phases.items() if v.get()])}
        proc = subprocess.Popen(["sudo", "-E", "bash", "./setup_r36ultra.sh"], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        lines = list(proc.stdout)
        for i, line in enumerate(lines):
            self.after(0, self.update_ui, i/len(lines)*100, line)
        proc.wait()

    def update_ui(self, p, line):
        self.canvas.itemconfig(self.arc, extent=-(p * 3.6))
        rad = math.radians(-(p * 3.6) + 90)
        self.canvas.coords(self.arm, 60, 60, 60+40*math.cos(rad), 60-40*math.sin(rad))
        self.pct.set(f"{int(p)}%")
        self.log_text.insert(tk.END, line)
        self.log_text.see(tk.END)

if __name__ == "__main__":
    PineREInstaller().mainloop()