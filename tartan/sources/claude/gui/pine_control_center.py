#!/usr/bin/env python3
import tkinter as tk
from tkinter import ttk, messagebox, filedialog
import subprocess, threading, os, sys, shutil

class PineREAdvancedUI(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("PineRE // Advanced Control Center")
        self.geometry("1000x700")
        self.configure(bg="#1A1A1C")
        
        self.running = False
        self.debug_mode = tk.BooleanVar(value=False)
        self.phases = {"Partition": tk.BooleanVar(value=True), "U-Boot": tk.BooleanVar(value=True), "Extract": tk.BooleanVar(value=True), "Packages": tk.BooleanVar(value=True), "Bootfiles": tk.BooleanVar(value=True)}

        # Main Layout: Sidebar vs Content
        self.sidebar = tk.Frame(self, bg="#2D2D35", width=250)
        self.sidebar.pack(side="left", fill="y")
        
        tk.Label(self.sidebar, text="PineRE OS", fg="#67308F", bg="#2D2D35", font=("Arial", 22, "bold")).pack(pady=20)
        
        # Central Spinner (Start Button)
        self.cv = tk.Canvas(self.sidebar, width=150, height=150, bg="#2D2D35", highlightthickness=0)
        self.cv.pack(pady=20)
        self.arc = self.cv.create_arc(30, 30, 120, 120, start=90, extent=0, outline="#67308F", width=6, style="arc")
        btn = self.cv.create_oval(50, 50, 100, 100, fill="#67308F", outline="")
        self.cv.create_text(75, 75, text="START", fill="white", font=("Arial", 10, "bold"))
        self.cv.tag_bind(btn, '<Button-1>', self.start_compile)

        # Tabbed Content
        style = ttk.Style()
        style.theme_use('clam')
        style.configure("TNotebook", background="#1A1A1C", borderwidth=0)
        style.configure("TNotebook.Tab", background="#2D2D35", foreground="white", padding=[10, 5])
        
        self.nb = ttk.Notebook(self)
        self.nb.pack(side="right", fill="both", expand=True, padx=10, pady=10)

        # Tab Frames
        self.f_drives = tk.Frame(self.nb, bg="#1A1A1C"); self.nb.add(self.f_drives, text="Drives")
        self.f_phases = tk.Frame(self.nb, bg="#1A1A1C"); self.nb.add(self.f_phases, text="Phases")
        self.f_about = tk.Frame(self.nb, bg="#1A1A1C"); self.nb.add(self.f_about, text="About/Debug")
        self.f_logs = tk.Frame(self.nb, bg="#1A1A1C"); self.nb.add(self.f_logs, text="Logs")

        self.setup_tabs()

    def setup_tabs(self):
        # Drives Tab
        tk.Label(self.f_drives, text="Target Device", fg="#67308F", bg="#1A1A1C", font=("Arial", 16)).pack(pady=20)
        self.dev_menu = ttk.Combobox(self.f_drives, state="readonly", width=40)
        self.dev_menu.pack(pady=10)
        tk.Button(self.f_drives, text="Refresh Drives", command=self.refresh_drives).pack()
        
        # Phases Tab
        tk.Label(self.f_phases, text="Compile Phases", fg="#67308F", bg="#1A1A1C", font=("Arial", 16)).pack(pady=20)
        for name, var in self.phases.items():
            tk.Checkbutton(self.f_phases, text=name, variable=var, bg="#1A1A1C", fg="white", selectcolor="#67308F").pack(anchor="w", padx=40, pady=2)
            
        # About Tab
        tk.Label(self.f_about, text="PineRE v1.5 // Musl Optimized", fg="#67308F", bg="#1A1A1C", font=("Arial", 16)).pack(pady=20)
        tk.Checkbutton(self.f_about, text="Enable Debug Mode (Green Spinner)", variable=self.debug_mode, bg="#1A1A1C", fg="white", selectcolor="#67308F").pack(pady=20)
        
        # Logs Tab
        self.log_txt = tk.Text(self.f_logs, bg="black", fg="#0F0", font=("Consolas", 10))
        self.log_txt.pack(fill="both", expand=True)

    def refresh_drives(self):
        try:
            o = subprocess.check_output("lsblk -n -o NAME,SIZE,LABEL -p -e 7 -d", shell=True).decode()
            self.dev_menu['values'] = [l.strip() for l in o.splitlines()]
        except: pass

    def start_compile(self, event):
        if self.running: return
        target = self.dev_menu.get().split()[0] if self.dev_menu.get() else None
        if not target: return
        
        self.running = True
        self.log_txt.delete(1.0, tk.END)
        self.nb.select(self.f_logs) # Auto-switch to logs tab
        threading.Thread(target=self.run_process, args=(target,), daemon=True).start()

    def run_process(self, dev):
        env = {**os.environ, "TARGET_DEV": dev, "SELECTED_PHASES": ",".join([n for n, v in self.phases.items() if v.get()])}
        proc = subprocess.Popen(["sudo", "-E", "bash", "./setup_r36ultra.sh"], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        
        angle = 0
        for line in proc.stdout:
            self.after(0, self.update_log, line)
            angle = (angle + 10) % 360
            color = "green" if self.debug_mode.get() else "#67308F"
            self.after(0, lambda: self.cv.itemconfig(self.arc, extent=-angle, outline=color))
            
        proc.wait()
        self.running = False
        self.after(0, lambda: self.cv.itemconfig(self.arc, extent=-359)) # Show complete
        if proc.returncode != 0:
            self.after(0, self.handle_crash)

    def update_log(self, line):
        self.log_txt.insert(tk.END, line)
        self.log_txt.see(tk.END)

    def handle_crash(self):
        if messagebox.askyesno("Error", "Crash detected. Save diagnostic logs?"):
            path = filedialog.asksaveasfilename(defaultextension=".txt", initialfile="pinere_crash.txt")
            if path: shutil.copy("/tmp/r36ultra_setup.log", path)

if __name__ == "__main__":
    app = PineREAdvancedUI()
    app.refresh_drives()
    app.mainloop()