#!/usr/bin/env bash

set -euo pipefail
B="http://localhost:7000"

curlq() {
  local desc="$1"
  shift
  echo "########## $desc ##########"
  echo "Команда: curl -sS -D - -o - $*"
  echo "---"
  curl -sS -D - -o - "$@" 2>&1 || echo "(curl exit: $?)"
  echo ""
  echo ""
}

# --- Подготовка данных ---
curlq "SETUP register stage3_base / Alice" -X POST "$B/register?userId=stage3_base&userName=Alice"
curlq "SETUP register stage3_xss / script name" -X POST "$B/register?userId=stage3_xss&userName=%3Cscript%3Ealert(1)%3C%2Fscript%3E"
curlq "SETUP register stage3_quote / quote in name" -X POST "$B/register?userId=stage3_quote&userName=O%27Reilly%22%3C%3E"
curlq "SETUP register stage3_sess / for sessions" -X POST "$B/register?userId=stage3_sess&userName=SessUser"
curlq "SETUP recordSession valid" -X POST "$B/recordSession?userId=stage3_sess&loginTime=2025-01-15T10:00:00&logoutTime=2025-01-15T11:30:00"
curlq "SETUP register stage3_month / monthly" -X POST "$B/register?userId=stage3_month&userName=M"
curlq "SETUP recordSession for monthlyActivity" -X POST "$B/recordSession?userId=stage3_month&loginTime=2025-01-10T08:00:00&logoutTime=2025-01-10T09:00:00"
curlq "SETUP register stage3_export" -X POST "$B/register?userId=stage3_export&userName=ExportUser"
curlq "SETUP register stage3_notify" -X POST "$B/register?userId=stage3_notify&userName=N"

# --- POST /register ---
curlq "POST /register — нет параметров" -X POST "$B/register"
curlq "POST /register — только userId" -X POST "$B/register?userId=onlyId"
curlq "POST /register — пустой userId (граничный случай)" -X POST "$B/register?userId=&userName=empty_id_user"
curlq "POST /register — дубликат userId" -X POST "$B/register?userId=stage3_base&userName=Other"
curlq "POST /register — userId со слэшами и точками" -X POST "$B/register?userId=..%2F..%2Fevil&userName=test"
curlq "POST /register — длинный userName (~800 символов)" -X POST "$B/register?userId=stage3_long&userName=$(python3 -c 'print("A"*800)')"

# --- POST /recordSession ---
curlq "POST /recordSession — нет параметров" -X POST "$B/recordSession"
curlq "POST /recordSession — битый ISO loginTime" -X POST "$B/recordSession?userId=stage3_sess&loginTime=not-a-date&logoutTime=2025-01-15T12:00:00"
curlq "POST /recordSession — неизвестный userId" -X POST "$B/recordSession?userId=no_such_user&loginTime=2025-01-15T10:00:00&logoutTime=2025-01-15T11:00:00"
curlq "POST /recordSession — logout раньше login (логика сервиса)" -X POST "$B/recordSession?userId=stage3_sess&loginTime=2025-01-20T12:00:00&logoutTime=2025-01-20T10:00:00"

# --- GET /totalActivity ---
curlq "GET /totalActivity — нет userId" "$B/totalActivity"
curlq "GET /totalActivity — несуществующий user" "$B/totalActivity?userId=ghost_user"
curlq "GET /totalActivity — норма" "$B/totalActivity?userId=stage3_sess"
curlq "GET /totalActivity — userId со спецсимволами в query" "$B/totalActivity?userId=stage3_%3Ctest%3E"

# --- GET /inactiveUsers ---
curlq "GET /inactiveUsers — нет days" "$B/inactiveUsers"
curlq "GET /inactiveUsers — days не число" "$B/inactiveUsers?days=abc"
curlq "GET /inactiveUsers — days отрицательное" "$B/inactiveUsers?days=-1"
curlq "GET /inactiveUsers — days=0" "$B/inactiveUsers?days=0"

# --- GET /monthlyActivity ---
curlq "GET /monthlyActivity — нет параметров" "$B/monthlyActivity"
curlq "GET /monthlyActivity — неверный month" "$B/monthlyActivity?userId=stage3_month&month=13-2025"
curlq "GET /monthlyActivity — пользователь без сессий (ожидание ошибки)" "$B/monthlyActivity?userId=stage3_base&month=2025-01"
curlq "GET /monthlyActivity — норма" "$B/monthlyActivity?userId=stage3_month&month=2025-01"

# --- GET /userProfile ---
curlq "GET /userProfile — нет userId" "$B/userProfile"
curlq "GET /userProfile — 404" "$B/userProfile?userId=nobody_here"
curlq "GET /userProfile — XSS user" "$B/userProfile?userId=stage3_xss"
curlq "GET /userProfile — кавычки в имени" "$B/userProfile?userId=stage3_quote"

# --- GET /exportReport ---
curlq "GET /exportReport — нет параметров" "$B/exportReport"
curlq "GET /exportReport — несуществующий user" "$B/exportReport?userId=ghost&filename=a.txt"
curlq "GET /exportReport — нормальное имя файла" "$B/exportReport?userId=stage3_export&filename=safe_report.txt"
curlq "GET /exportReport — path traversal (../)" "$B/exportReport?userId=stage3_export&filename=..%2F..%2Ftmp%2Flab4_escape.txt"

# --- POST /notify ---
curlq "POST /notify — нет параметров" -X POST "$B/notify"
curlq "POST /notify — несуществующий user" -X POST "$B/notify?userId=ghost&callbackUrl=http://127.0.0.1:1/"
curlq "POST /notify — невалидный URL" -X POST "$B/notify?userId=stage3_notify&callbackUrl=not-a-url"
curlq "POST /notify — connection refused (порт закрыт)" -X POST "$B/notify?userId=stage3_notify&callbackUrl=http://127.0.0.1:1/nope"
curlq "POST /notify — file:// схема" -X POST "$B/notify?userId=stage3_notify&callbackUrl=file:///etc/passwd"

echo "########## RATE — 20x GET /totalActivity подряд (коды) ##########"
for i in $(seq 1 20); do
  code=$(curl -s -o /dev/null -w "%{http_code}" "$B/totalActivity?userId=stage3_sess")
  echo -n "$code "
done
echo ""

echo "DONE"
