#!/bin/bash

die(){ echo "Ошибка: $*" >&2; exit 1; }

CREATE_DISK=false
THRESHOLD=70
DIR=""

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -p|--path) DIR="$2"; shift 2 ;;
    -t|--threshold) THRESHOLD="$2"; shift 2 ;;
    --create-disk) CREATE_DISK=true; shift ;;
    -h|--help)
      echo "Использование: $0 [--create-disk] --path /путь/до/папки --threshold 70"
      exit 0 ;;
    *) echo "Неизвестный параметр: $1"; exit 1 ;;
  esac
done

if $CREATE_DISK; then
  DISK_IMG="$(mktemp --tmpdir diskXXXX.img)"
  MOUNT_POINT="$(mktemp -d)"
  echo "Создаём виртуальный диск 600MB..."
  dd if=/dev/zero of="$DISK_IMG" bs=1M count=600 status=none || die "Ошибка dd"
  mkfs.ext4 -q "$DISK_IMG" || die "Ошибка форматирования"
  guestmount -a "$DISK_IMG" -m /dev/sda1 "$MOUNT_POINT" || die "Ошибка монтирования"
  DIR="$MOUNT_POINT/log"
  mkdir -p "$DIR"
  echo "Создан и смонтирован виртуальный диск в $MOUNT_POINT"
fi

[ -z "$DIR" ] && die "Не указан путь"
[ ! -d "$DIR" ] && die "Папка $DIR не существует"

echo "Проверяем заполненность для $DIR..."
USAGE=$(df -h "$DIR" | awk 'NR==2 {print $5}' | tr -d '%')
echo "Папка $DIR расположена на диске, заполненность = $USAGE%"

if [ "$USAGE" -lt "$THRESHOLD" ]; then
  echo "Текущая заполненность меньше порога $THRESHOLD%. Архивация не требуется."
else
  echo "Заполненность превышает порог $THRESHOLD%. Выполняется архивация."
  BACKUP_DIR="$DIR/backup"
  mkdir -p "$BACKUP_DIR"
  FILES=($(find "$DIR" -maxdepth 1 -type f -printf '%T@ %p\n' | sort -n | awk '{print $2}'))
  COUNT=${#FILES[@]}
  N=$(( COUNT * 10 / 100 ))
  [ "$N" -lt 1 ] && N=1
  echo "Всего файлов: $COUNT. Будет заархивировано $N старейших."
  ARCHIVE_NAME="$BACKUP_DIR/backup_$(date +%Y%m%d_%H%M%S).tar"
  for (( i=0; i<N; i++ )); do
    FILE="${FILES[$i]}"
    tar -rf "$ARCHIVE_NAME" "$FILE"
    echo "Добавлен в архив: $FILE"
    rm -f "$FILE"
  done
  gzip "$ARCHIVE_NAME"
  echo "Архивация завершена. Создан архив $(basename "$ARCHIVE_NAME").gz"
fi

if $CREATE_DISK; then
  echo "Отмонтируем виртуальный диск..."
  guestunmount "$MOUNT_POINT"
  rm -f "$DISK_IMG"
  rm -rf "$MOUNT_POINT"
  echo "Виртуальный диск удалён."
fi

echo "Работа завершена успешно."
exit 0
