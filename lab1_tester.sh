#!/bin/bash

SCRIPT="${1:-./check_usage.sh}"
FILES=12
SIZE_MB=50

die(){ echo "Ошибка: $*" >&2; exit 1; }
[ -x "$SCRIPT" ] || die "не найден исполняемый $SCRIPT"

mkdata(){
  BASE="$(mktemp -d)" || die "mktemp"
  LOG="$BASE/log"; mkdir -p "$LOG"
  i=1
  while [ $i -le $FILES ]; do
    dd if=/dev/zero of="$LOG/f_$i.bin" bs=1M count=$SIZE_MB status=none
    touch -d "$i hours ago" "$LOG/f_$i.bin"
    i=$((i+1))
  done
  SZ=$(du -sm "$LOG" | awk '{print $1}')
  [ "$SZ" -ge 500 ] || die "создано ${SZ}MB (<500MB)"
}

before_lists(){
  find "$LOG" -maxdepth 1 -type f | sort > "$BASE/before_all.txt"
  FC=$(wc -l < "$BASE/before_all.txt")
  N=$(( FC*10/100 ))
  [ "$N" -lt 1 ] && N=1
  find "$LOG" -maxdepth 1 -type f -printf '%T@ %p\n' | sort -n | head -n "$N" \
    | cut -d' ' -f2- | sort > "$BASE/expected_oldest.txt"
}

after_lists(){
  find "$LOG" -maxdepth 1 -type f | sort > "$BASE/after_all.txt"
  grep -vxF -f "$BASE/after_all.txt" "$BASE/before_all.txt" > "$BASE/removed.txt"
}

check_none(){
  ARC=$(find "$LOG/backup" -type f -name 'backup_*.tar.gz' 2>/dev/null | wc -l)
  REM=$(wc -l < "$BASE/removed.txt")
  [ "$ARC" -eq 0 ] && [ "$REM" -eq 0 ] || die "не ожидалась архивация/удаление"
  echo "OK: архивации нет"
}

check_archive(){
  ARC=$(find "$LOG/backup" -type f -name 'backup_*.tar.gz' 2>/dev/null | wc -l)
  REM=$(wc -l < "$BASE/removed.txt")
  [ "$ARC" -ge 1 ] || die "архив не создан"
  [ "$REM" -eq "$N" ] || die "удалено $REM, ожидалось N=$N"
  MISSED=$(grep -vxF -f "$BASE/removed.txt" "$BASE/expected_oldest.txt" | wc -l)
  [ "$MISSED" -eq 0 ] || { echo "Ожидались:"; cat "$BASE/expected_oldest.txt"; echo "Удалены:"; cat "$BASE/removed.txt"; die "нарушено правило N старейших"; }
  echo "OK: создан архив, удалены N старейших"
}

run(){
  NAME="$1"; THR="$2"; EXPECT="$3"
  echo; echo "== $NAME =="
  mkdata
  before_lists
  echo "Порог: $THR%, файлов: $FC, N=$N"
  "$SCRIPT" "$LOG" "$THR" > "$BASE/out.txt" 2> "$BASE/err.txt" || true
  head -n 10 "$BASE/out.txt"
  after_lists
  if [ "$EXPECT" = none ]; then check_none; else check_archive; fi
  rm -rf "$BASE"
}

echo "Тестирую $(basename "$SCRIPT")"
run "T1: 99%" 99 none
run "T2: 100%" 100 none
run "T3: 1%" 1 archive
run "T4: 0%" 0 archive
echo "Готово"

