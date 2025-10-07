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
  echo "Превышен порог $THRESHOLD%"
  exit 2
else
  echo "Все нормально"
  exit 0
fi