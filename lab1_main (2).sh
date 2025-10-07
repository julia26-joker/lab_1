#!/bin/bash

DIR=$1
THRESHOLD=${2:-70}   # порог, обычно 70%

if [ -z "$DIR" ]; then
  echo "Использование: $0 <папка> [порог]"
  exit 1
fi

if [ ! -d "$DIR" ]; then
  echo "Ошибка: папка $DIR не существует"
  exit 1
fi

USAGE=$(df -h "$DIR" | awk 'NR==2 {print $5}' | tr -d '%')
echo "Папка $DIR расположена на диске, заполненность = $USAGE%"

if [ "$USAGE" -ge "$THRESHOLD" ]; then
  echo "Превышен порог $THRESHOLD%, приступаем к архивации."

  BACKUP_DIR="${DIR}/backup"

  if [ ! -d "$BACKUP_DIR" ]; then
    echo "Папка для архивации $BACKUP_DIR не найдена, создаем..."
    mkdir -p "$BACKUP_DIR"
  fi

  FILE_COUNT=$(find "$DIR" -maxdepth 1 -type f | wc -l)

  N=$(echo "$FILE_COUNT * 10 / 100" | bc)
  if [ "$N" -lt 1 ]; then
    N=1
  fi

  echo "Будут архивированы $N файла(ов) из $FILE_COUNT."

  FILES_TO_ARCHIVE=$(find "$DIR" -maxdepth 1 -type f | head -n "$N")

  if [ -z "$FILES_TO_ARCHIVE" ]; then
    echo "Нет файлов для архивации."
    exit 0
  fi

  TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
  ARCHIVE_NAME="${BACKUP_DIR}/backup_${TIMESTAMP}.tar.gz"

  echo "Архивируем файлы в $ARCHIVE_NAME..."
  tar -czf "$ARCHIVE_NAME" $FILES_TO_ARCHIVE

  echo "Удаляем архивированные файлы из $DIR..."
  for FILE in $FILES_TO_ARCHIVE; do
    rm -f "$FILE"
  done

  echo "Архивация и очистка завершены."

else
  echo "Заполненность диска в пределах порога, ничего не делаем."
fi

exit 0