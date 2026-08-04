#!/usr/bin/env bash
# shellcheck shell=bash
# dietpex OS - Thai messages (ข้อความภาษาไทย)
# Define the msg() function. Keys are looked up by the installer and helpers.

msg() {
  case "$1" in
    title)                 printf '%s\n' "โปรแกรมติดตั้ง dietpex OS";;
    need_root)             printf '%s\n' "ต้องรันด้วยสิทธิ์ root (ลอง: sudo bash install.sh)";;
    os_unsupported)        printf '%s\n' "ระบบปฏิบัติการหรือสภาพแวดล้อมนี้ยังไม่รองรับ";;
    os_detected)           printf '%s\n' "ตรวจพบ: ";;
    env_wsl)               printf '%s\n' "Windows Subsystem for Linux (WSL)";;
    env_linux_apt)         printf '%s\n' "Linux ที่ใช้ apt (ตระกูล Ubuntu)";;
    env_live)              printf '%s\n' "สภาพแวดล้อม Live USB";;
    menu_title)            printf '%s\n' "ต้องการให้ทำอะไร?";;
    opt_full)              printf '%s\n' "1) ติดตั้งแบบเต็ม (ติดตั้งระบบ + ลด bloat + ติดตั้ง XFCE)";;
    opt_trim)              printf '%s\n' "2) ลด bloat อย่างเดียว (ปิดบริการที่ไม่จำเป็น)";;
    opt_ui)                printf '%s\n' "3) ติดตั้ง XFCE อย่างเดียว";;
    opt_dualboot)          printf '%s\n' "4) ตั้งค่า dual-boot (เมนู GRUB)";;
    opt_windows)           printf '%s\n' "5) ติดตั้งภายใน Windows (WSL2)";;
    opt_usb)               printf '%s\n' "6) สร้าง USB สำหรับติดตั้งจาก ISO ของ Ubuntu";;
    opt_thai)              printf '%s\n' "7) ติดตั้งฟอนต์ภาษาไทย + การรองรับภาษา";;
    opt_quit)              printf '%s\n' "0) ออกจากโปรแกรม";;
    enter_choice)          printf '%s\n' "ป้อนตัวเลือก: ";;
    invalid_choice)        printf '%s\n' "ตัวเลือกไม่ถูกต้อง";;
    apt_update)            printf '%s\n' "กำลังอัปเดตรายการแพ็กเกจ...";;
    installing_xfce)       printf '%s\n' "กำลังติดตั้งเดสก์ท็อป XFCE...";;
    xfce_installed)        printf '%s\n' "ติดตั้ง XFCE เสร็จแล้ว";;
    purging_gnome)         printf '%s\n' "กำลังลบ GNOME...";;
    gnome_purged)          printf '%s\n' "ลบ GNOME เสร็จแล้ว";;
    trim_started)          printf '%s\n' "เริ่มลด bloat...";;
    trim_done)             printf '%s\n' "ลด bloat เสร็จแล้ว";;
    dualboot_start)        printf '%s\n' "เริ่มตั้งค่า dual-boot (เมนู GRUB)...";;
    dualboot_done)         printf '%s\n' "ตั้งค่า dual-boot เสร็จแล้ว";;
    wsl_start)             printf '%s\n' "เริ่มติดตั้งภายใน WSL...";;
    wsl_done)              printf '%s\n' "ติดตั้งภายใน WSL เสร็จแล้ว";;
    wsl_gui_hint)          printf '%s\n' "เริ่มเดสก์ท็อปทีหลังด้วยคำสั่ง: startxfce4  (Windows 11 WSLg รองรับ GUI)";;
    usb_confirm)           printf '%s\n' "คำสั่งนี้จะลบข้อมูลทั้งหมดในอุปกรณ์เป้าหมาย พิมพ์ YES เพื่อยืนยัน: ";;
    usb_confirm_device)    printf '%s\n' "อุปกรณ์เป้าหมาย (เช่น /dev/sdb): ";;
    usb_start)             printf '%s\n' "กำลังเขียน ISO ลง USB...";;
    usb_done)              printf '%s\n' "สร้าง USB ที่บูตได้แล้ว";;
    reboot_hint)           printf '%s\n' "แนะนำให้รีบูตเครื่อง: sudo reboot";;
    complete)              printf '%s\n' "การติดตั้งเสร็จสมบูรณ์";;
    thai_start)            printf '%s\n' "กำลังติดตั้งฟอนต์ภาษาไทยและการรองรับภาษา...";;
    thai_done)             printf '%s\n' "ติดตั้งฟอนต์และการรองรับภาษาไทยเสร็จแล้ว";;
    locale_set)            printf '%s\n' "ตั้งค่าภาษาของระบบเป็น th_TH.UTF-8 แล้ว (รีบูตเพื่อใช้งาน)";;
    thai_hint)             printf '%s\n' "ภาษาไทยจะแสดงผลถูกต้องบนเว็บไซต์ เบราว์เซอร์ (Google) และแอปพลิเคชัน";;
    noto_note)             printf '%s\n' "กำลังติดตั้งฟอนต์ Noto เพิ่ม (ภาษาไทยบนเว็บ Google สวยขึ้น)...";;
    * )                    printf '%s\n' "$*";;
  esac
}
