# PineRE

PineRE is an Alpine Linux-based operating system for RK3326 handheld gaming devices.

The long-term goal is to provide a lightweight, open, modular platform capable of running emulation frontends, desktop environments, and Android applications while remaining suitable for devices with limited resources.

## Current Development Branch

**Tartan**

Tartan is the current development stage of PineRE and focuses on establishing a stable Alpine Linux foundation for the R36 Ultra, including hardware support, multi-mode booting, and EmulationStation integration.

## Project Status

**Early Development**

PineRE is under active development and is not yet considered bootable on target hardware.

Current efforts focus on:

- Alpine Linux bring-up
- RK3326 platform support
- EmulationStation compilation
- Multi-mode boot infrastructure
- Storage layout design
- Hardware abstraction planning

## Current Hardware Target

- R36 Ultra (RK3326)

Future releases are planned to support additional RK3326-based handheld devices once the R36 Ultra platform is stable.

## Project Goals

- Alpine Linux base
- OpenRC service management
- RK3326 support
- Fast boot times
- Low memory usage
- EmulationStation frontend
- XFCE desktop mode
- Waydroid support
- U-Boot boot mode selection
- Shared hardware abstraction layer
- Dedicated ROM storage partition

## Planned Boot Modes

| Mode | Function |
|--------|----------|
| Default | EmulationStation |
| L1 | Minimal maintenance shell |
| R1 | XFCE desktop |
| R2 | Weston/Cage with Waydroid |

Boot mode selection is planned through button detection during the U-Boot stage.

## Planned Storage Layout

| Partition | Purpose |
|------------|-----------|
| BOOT | Bootloader and kernel files |
| ROOT | Alpine Linux root filesystem |
| EASYROMS | User ROM and content storage |

This design allows system updates and recovery without affecting user content.

## Planned Features

- EmulationStation frontend
- XFCE desktop environment
- Waydroid support
- Controller abstraction layer
- LED ring effects
- Battery monitoring
- Brightness control
- USB OTG support
- USB gadget networking
- SSH over USB

## Vision

PineRE aims to become a flexible RK3326 platform that can provide a console-like gaming experience, lightweight desktop functionality, and Android application support while remaining efficient enough to run on devices with only 1 GB of RAM.

---

**Current Development Codename:** Tartan
