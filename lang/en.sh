#!/usr/bin/env bash
# shellcheck shell=bash
# dietpex OS - English messages
# Define the msg() function. Keys are looked up by the installer and helpers.

msg() {
  case "$1" in
    title)                 printf '%s\n' "dietpex OS installer";;
    need_root)             printf '%s\n' "This installer must be run as root. Try: sudo bash install.sh";;
    os_unsupported)        printf '%s\n' "Unsupported OS or environment.";;
    os_detected)           printf '%s\n' "Detected: ";;
    env_wsl)               printf '%s\n' "Windows Subsystem for Linux (WSL)";;
    env_linux_apt)         printf '%s\n' "Linux with apt (Ubuntu family)";;
    env_live)              printf '%s\n' "Live USB environment";;
    menu_title)            printf '%s\n' "What would you like to do?";;
    opt_full)              printf '%s\n' "1) Full install (base + dietpex trim + XFCE UI)";;
    opt_trim)              printf '%s\n' "2) Trim only (dietpex: disable services, purge bloat)";;
    opt_ui)                printf '%s\n' "3) Install XFCE UI only";;
    opt_dualboot)          printf '%s\n' "4) Set up dual-boot GRUB menu";;
    opt_windows)           printf '%s\n' "5) Install inside Windows (WSL2)";;
    opt_usb)               printf '%s\n' "6) Create a bootable USB from the Ubuntu ISO";;
    opt_quit)              printf '%s\n' "0) Quit";;
    enter_choice)          printf '%s\n' "Enter your choice: ";;
    invalid_choice)        printf '%s\n' "Invalid choice.";;
    apt_update)            printf '%s\n' "Updating package lists...";;
    installing_xfce)       printf '%s\n' "Installing XFCE desktop...";;
    xfce_installed)        printf '%s\n' "XFCE desktop installed.";;
    purging_gnome)         printf '%s\n' "Removing GNOME desktop...";;
    gnome_purged)          printf '%s\n' "GNOME removed.";;
    trim_started)          printf '%s\n' "Starting dietpex trim...";;
    trim_done)             printf '%s\n' "dietpex trim complete.";;
    dualboot_start)        printf '%s\n' "Setting up dual-boot GRUB menu...";;
    dualboot_done)         printf '%s\n' "Dual-boot menu configured.";;
    wsl_start)             printf '%s\n' "Installing inside WSL...";;
    wsl_done)              printf '%s\n' "WSL install complete.";;
    wsl_gui_hint)          printf '%s\n' "To start the desktop later, run: startxfce4  (Windows 11 WSLg supports GUI)";;
    usb_confirm)           printf '%s\n' "This will DESTROY all data on the target device. Type YES to continue: ";;
    usb_confirm_device)    printf '%s\n' "Target device (e.g. /dev/sdb): ";;
    usb_start)             printf '%s\n' "Writing ISO to USB...";;
    usb_done)              printf '%s\n' "Bootable USB created.";;
    reboot_hint)           printf '%s\n' "A reboot is recommended: sudo reboot";;
    complete)              printf '%s\n' "Installation complete.";;
    * )                    printf '%s\n' "$*";;
  esac
}
