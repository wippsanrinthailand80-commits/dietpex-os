#!/bin/bash
# dietpex OS - demo shown on the live desktop via XDG autostart.
# Proves Thai text renders correctly in a real GUI session.
set -uo pipefail

LOG=/home/dietpex/dietpex-demo.log
mkdir -p "$(dirname "$LOG")" 2>/dev/null || LOG=/tmp/dietpex-demo.log
echo "dietpex-demo.sh started at $(date)" >> "$LOG" 2>/dev/null || true

while true; do
  clear 2>/dev/null || true
  printf '\033[36m\033[1m'
  echo "  ____  _            __   ____  ____  _____  ____"
  echo " |  _ \| |_   _  ___ \ \ / / _ \| __ )| ____|  _ "
  echo " | | | | | | | |/ _ \ \ V / | | |  _ \|  _| | |_) |"
  echo " | |_| | | |_| |  __/ | | | | |_| | |_) | |___|  __/"
  echo " |____/|_|\__,_|\___|  |_| \___/|____/|_____|_|"
  printf '\033[0m'
  echo
  echo "สวัสดีครับ ยินดีต้อนรับสู่ dietpex OS"
  echo "Welcome to dietpex OS - a trimmed Ubuntu with XFCE + Thai support"
  echo
  echo "───────────────── ไทย Test  ─────────────────"
  echo "สระบน (above vowels):  กิ กี กึ กื กำ ก็ ก่ ก้ ก๊ ก๋"
  echo "สระล่าง (below vowels): กุ กู"
  echo "เต็มประโยค:  กินข้าวที่ร้านอาหารอร่อยมาก"
  echo "ตัวเลข:  อาหาร 5 จาน ราคา 350 บาท"
  echo "คำประสม:  เดี๋ยว นึก คิดถึง รู้สึก"
  echo "──────────────────────────────────────────────"
  echo
  printf 'fc-match ":lang=th" -> %s\n' "$(fc-match ':lang=th' 2>/dev/null || echo 'FAILED')"
  printf 'Locale: %s\n' "$(locale 2>/dev/null | grep LANG | head -1 || echo 'FAILED')"
  echo
  echo "การทดสอบนี้แสดงผลบนเดสก์ท็อปจริง (This renders on the real desktop)"
  echo "demo frame drawn at $(date)" >> "$LOG" 2>/dev/null || true
  sleep 60
done
