# PineRE Tartan v0.01 Boot Test

Goal:
BootROM -> idbloader.img -> u-boot.itb -> extlinux.conf -> Linux -> Alpine -> Login Prompt

Required Layout:

boot/
  Image
  rk3326-r36ultra-linux.dtb
  extlinux/extlinux.conf

alpine-files/
  alpine-minirootfs-3.23.4-aarch64.tar.gz

install/u-boot/
  idbloader.img
  u-boot.itb
