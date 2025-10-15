#!/bin/bash

SCRIPT="${1:-./lab1_main.sh}"
DISK_IMG="virtual_disk.img"
MOUNT_DIR="/mnt/testdisk"
DISK_SIZE_MB=900
FILES=20
SIZE_MB=30

die(){ echo "Ошибка: $*" >&2; exit 1; }
[ -x "$SCRIPT" ] || die "не найден исполняемый $SCRIPT"

make_disk(){
  echo "Создаём виртуальный диск ${DISK_SIZE_MB}MB..."
  sudo dd if=/dev/zero of="$DISK_IMG" bs=1M count="$DISK_SIZE_MB" status=none || die "dd"
  sudo mkfs.ext4 -q "$DISK_IMG" || die "mkfs.ext4"
  sudo mkdir -p "$MOUNT_DIR"
  sudo mount -o loop "$DISK_IMG" "$MOUNT_DIR" || die "mount"
  sudo chown -R "$USER":"$USER" "$MOUNT_DIR"
}

umount_disk(){
  echo "Очищаем виртуальный диск..."
  sudo umount "$MOUNT_DIR" 2>/dev/null
  sudo rm -f "$DISK_IMG"
  sudo rmdir "$MOUNT_DIR" 2>/dev/null
}

mkdata(){
  BASE="$MOUNT_DIR/tmpdata"
  LOG="$BASE/log"
  mkdir -p "$LOG"
  for i in $(seq 1 "$FILES"); do
    dd if=/dev/zero of="$LOG/f_${i}.bin" bs=1M count="$SIZE_MB" status=none
    touch -d "$i hours ago" "$LOG/f_${i}.bin"
  done
  SZ=$(du -sm "$LOG" | awk '{print $1}')
  if [ "$SZ" -lt 500 ]; then
    die "создано ${SZ}MB (<500MB)"
  fi
  echo "$LOG"
}

run_case(){
  NAME="$1"; THR="$2"; EXPECT="$3"
  echo
  echo "== $NAME =="
  make_disk
  LOG=$(mkdata)
  FC=$(find "$LOG" -maxdepth 1 -type f | wc -l)
  N=$(( FC*10/100 )); [ "$N" -lt 1 ] && N=1
  echo "Порог: $THR%, файлов: $FC, N=$N"
  "$SCRIPT" --path "$LOG" --threshold "$THR"
  if [ "$EXPECT" = "archive" ]; then
    ARC_CNT=$(find "$LOG/backup" -maxdepth 1 -type f -name 'backup_*.tar.gz' 2>/dev/null | wc -l)
    if [ "$ARC_CNT" -ge 1 ]; then
      echo "Архивация выполнена (найдено архивов: $ARC_CNT)"
    else
      echo "Ошибка: архив не найден"
    fi
  else
    echo "Архивации нет"
  fi
  umount_disk
}

echo "Тестирую $SCRIPT на виртуальном диске (loop)."
run_case "T1: 99% — ничего" 99 none
run_case "T2: 100% — ничего" 100 none
run_case "T3: 1% — архивация" 1 archive
run_case "T4: 0% — архивация" 0 archive
echo
echo "Готово."
