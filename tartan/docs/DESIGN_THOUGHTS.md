# PineRE Design Thoughts

> Living design document for PineRE and the current Tartan development cycle.
>
> This document records ideas, architectural decisions, goals, and future considerations.
> Not everything listed here is implemented.

---

# Project Overview

PineRE is an Alpine Linux-based operating system targeting RK3326 handheld devices.

The project began with the goal of creating a lightweight, flexible platform capable of supporting:

- Emulation
- Desktop environments
- Android applications
- Development and maintenance workflows

while remaining usable on hardware with as little as 1 GB of RAM.

Current development codename: **Tartan**

Current target hardware: **R36 Ultra**

Future support is planned for additional RK3326-based handhelds.

---

# Core Philosophy

PineRE should not attempt to run every service at once.

Instead, the system should boot into purpose-built modes selected during startup.

This approach:

- Reduces memory usage
- Improves boot times
- Simplifies troubleshooting
- Allows Android and desktop functionality without dedicated installations

---

# Boot Mode Concept

Planned U-Boot button detection will select the operating mode before Linux starts.

Proposed modes:

| Button | Mode |
|----------|----------|
| None | EmulationStation |
| L1 | Maintenance Shell |
| R1 | XFCE Desktop |
| R2 | Weston/Cage + Waydroid |

The selected mode should be passed through the kernel command line and handled by OpenRC during startup.

---

# Storage Layout

Planned partition structure:

1. BOOT
2. ROOT
3. EASYROMS

## BOOT

Contains:

- U-Boot
- Kernel
- Device trees
- Boot configuration

## ROOT

Contains:

- Alpine Linux
- OpenRC services
- Applications
- System configuration

## EASYROMS

Contains:

- ROMs
- BIOS files
- User content

Reasons:

- System updates do not affect ROMs.
- Easier recovery.
- Easier migration between PineRE versions.
- Improved user experience.

---

# Hardware Abstraction

A common hardware layer should eventually exist.

Possible responsibilities:

- Controller input
- Analog sticks
- Battery monitoring
- Charging state
- LEDs
- Brightness control
- Volume control

Applications should not directly interact with hardware where possible.

This keeps behaviour consistent across boot modes.

---

# Controller Handling

Controller access should be available to all environments.

Possible approach:

- Early boot service
- Common input mapping
- Shared device access

Goal:

One implementation that works across:

- EmulationStation
- XFCE
- Waydroid
- Maintenance shell tools

---

# Android Support

Waydroid is preferred over maintaining a separate Android ROM.

Benefits:

- Shared Linux base
- Reduced maintenance burden
- Faster switching between environments
- Consistent storage layout

Challenges:

- 1 GB RAM limitation
- GPU compatibility
- Container performance

Waydroid should launch only when required.

---

# USB Development Features

Investigation required:

- USB gadget networking
- SSH over USB
- Dynamic OTG switching

Potential goal:

Connect device to PC and immediately gain shell access.

Potential issue:

USB gadget and USB host modes may conflict.

A software-controlled switching mechanism may be required.

---

# LED Ring Support

Planned features:

- Rainbow effects
- Battery indicators
- Charging indicators
- Status notifications
- Custom profiles

LED support should be available to all operating modes.

---

# Build Automation

Long-term goal:

Single setup process that:

1. Detects SD card
2. Creates partitions
3. Installs bootloader
4. Installs PineRE
5. Creates EASYROMS partition
6. Applies configuration

The objective is to simplify testing and deployment.

---

# Future Device Support

Current focus:

- R36 Ultra

Future possibilities:

- Additional RK3326 handhelds

Board-specific code should remain isolated where practical to simplify future ports.

---

# Tartan Milestones

Current known goals:

- Reliable Alpine boot
- EmulationStation compilation
- Storage layout implementation
- Boot mode infrastructure
- Hardware service design
- Controller support
- Display support
- Audio support

---

# Notes

This file is intentionally informal.

Ideas may be added, modified, or removed as PineRE evolves.
