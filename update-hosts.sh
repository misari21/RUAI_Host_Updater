#!/bin/bash
set -euo pipefail

REPO_OWNER="AvenCores"
REPO_NAME="Unlock_AI_and_EN_Services_for_Russia"
FILE_PATH="source/system/etc/hosts"
CANDIDATE_REFS=("main" "master")
RAW_URL=""
REMOTE_ETAG=""
STATE_DIR="/var/db/avencores-hosts-updater"
STATE_FILE="${STATE_DIR}/last_etag"
LOCK_DIR="${STATE_DIR}/lock"
TARGET_FILE="/private/etc/hosts"
LOG_TAG="avencores-hosts-updater"
USE_COLOR=0
RUN_STARTED_AT="$(/bin/date +%s)"
RESULT_STATUS="error"
if [[ -t 1 ]]; then
  USE_COLOR=1
fi

if [[ "${USE_COLOR}" -eq 1 ]]; then
  C_RESET="\033[0m"
  C_BLUE="\033[34m"
  C_GREEN="\033[32m"
  C_YELLOW="\033[33m"
  C_RED="\033[31m"
else
  C_RESET=""
  C_BLUE=""
  C_GREEN=""
  C_YELLOW=""
  C_RED=""
fi

print_header() {
  /usr/bin/printf "%b\n" "${C_BLUE}============================================================${C_RESET}"
  /usr/bin/printf "%b\n" "${C_BLUE} AvenCores Hosts Updater (macOS)${C_RESET}"
  /usr/bin/printf "%b\n" "${C_BLUE}============================================================${C_RESET}"
}

print_step() {
  /usr/bin/printf "%b\n" "${C_BLUE}==>${C_RESET} $*"
}

print_ok() {
  /usr/bin/printf "%b\n" "${C_GREEN}[OK]${C_RESET} $*"
}

print_warn() {
  /usr/bin/printf "%b\n" "${C_YELLOW}[WARN]${C_RESET} $*"
}

print_err() {
  /usr/bin/printf "%b\n" "${C_RED}[ERROR]${C_RESET} $*" >&2
}

print_summary() {
  local finished_at elapsed
  finished_at="$(/bin/date +%s)"
  elapsed="$((finished_at - RUN_STARTED_AT))"
  /usr/bin/printf "%b\n" "${C_BLUE}------------------------------------------------------------${C_RESET}"
  case "${RESULT_STATUS}" in
    updated)
      print_ok "Итог: файл hosts обновлен (updated)"
      ;;
    no_update)
      print_ok "Итог: обновление не требуется (up-to-date)"
      ;;
    locked)
      print_warn "Итог: пропуск, уже выполняется другой процесс (locked)"
      ;;
    *)
      print_err "Итог: выполнение завершилось с ошибкой (failed)"
      ;;
  esac
  print_step "Время выполнения: ${elapsed} сек"
}

log() {
  /bin/echo "[$(/bin/date '+%Y-%m-%d %H:%M:%S')] $*"
  /usr/bin/logger -t "${LOG_TAG}" "$*"
}

on_error() {
  local line="$1"
  local cmd="$2"
  print_err "Необработанная ошибка в строке ${line}: ${cmd}"
  log "Unhandled error at line ${line}: ${cmd}"
}

resolve_remote_source() {
  local ref=""
  local url=""
  local headers=""
  local etag=""
  for ref in "${CANDIDATE_REFS[@]}"; do
    url="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${ref}/${FILE_PATH}"
    if headers="$(
      /usr/bin/curl -A "avencores-hosts-updater/1.1" -fsSIL "${url}" 2>/dev/null
    )"; then
      etag="$(/bin/echo "${headers}" | /usr/bin/awk -F': ' 'tolower($1)=="etag" {gsub("\r", "", $2); print $2; exit}')"
      if [[ -n "${etag}" ]]; then
        RAW_URL="${url}"
        REMOTE_ETAG="${etag}"
        return 0
      fi
    fi
  done
  return 1
}

cleanup() {
  [[ -n "${TMP_FILE:-}" && -f "${TMP_FILE}" ]] && /bin/rm -f "${TMP_FILE}"
  [[ -d "${LOCK_DIR}" ]] && /bin/rmdir "${LOCK_DIR}" 2>/dev/null || true
}

on_exit() {
  cleanup
  print_summary
}

trap 'on_error "${LINENO}" "${BASH_COMMAND}"' ERR
trap on_exit EXIT

/bin/mkdir -p "${STATE_DIR}"
print_header
print_step "Старт проверки обновлений hosts"
log "Starting run"

if ! /bin/mkdir "${LOCK_DIR}" 2>/dev/null; then
  RESULT_STATUS="locked"
  print_warn "Уже выполняется другой процесс обновления."
  log "Another update process is already running."
  exit 0
fi

print_step "Определение источника hosts"
if ! resolve_remote_source; then
  print_err "Не удалось найти файл hosts в ветках: ${CANDIDATE_REFS[*]}"
  log "Could not resolve source hosts file from refs: ${CANDIDATE_REFS[*]}"
  exit 1
fi
print_ok "Источник: ${RAW_URL}"

LOCAL_ETAG=""
if [[ -f "${STATE_FILE}" ]]; then
  LOCAL_ETAG="$(/bin/cat "${STATE_FILE}")"
fi

print_step "Сравнение версий"
print_step "Удаленный ETag: ${REMOTE_ETAG}"
if [[ -n "${LOCAL_ETAG}" ]]; then
  print_step "Локальный ETag: ${LOCAL_ETAG}"
else
  print_step "Локальный ETag: <empty>"
fi

if [[ "${REMOTE_ETAG}" == "${LOCAL_ETAG}" ]]; then
  RESULT_STATUS="no_update"
  print_ok "Обновление не требуется. Файл hosts уже актуален."
  log "No hosts update available."
  exit 0
fi

print_step "Скачивание новой версии hosts"
TMP_FILE="$(/usr/bin/mktemp /tmp/hosts.XXXXXX)"
if ! /usr/bin/curl -A "avencores-hosts-updater/1.1" -fsSL "${RAW_URL}" -o "${TMP_FILE}"; then
  print_err "Не удалось скачать файл hosts: ${RAW_URL}"
  log "Failed to download hosts file from ${RAW_URL}."
  exit 1
fi

if [[ ! -s "${TMP_FILE}" ]]; then
  print_err "Скачанный файл hosts пустой"
  log "Downloaded hosts file is empty."
  exit 1
fi

if ! /usr/bin/grep -qE '^[[:space:]]*((([0-9]{1,3}\.){3}[0-9]{1,3})|(::1)|([0-9a-fA-F:]+))[[:space:]]+[[:graph:]]+' "${TMP_FILE}"; then
  print_err "Ошибка валидации: в файле нет корректных host-мэппингов"
  log "Downloaded file does not look like a valid hosts file (no host mapping lines)."
  exit 1
fi

if ! /usr/bin/grep -qE '^[[:space:]]*127\.0\.0\.1[[:space:]]+localhost([[:space:]]|$)' "${TMP_FILE}"; then
  print_warn "В файле не найдена запись localhost (это предупреждение, не ошибка)"
  log "localhost record not found in downloaded file."
fi
print_ok "Валидация пройдена"

if [[ -f "${TARGET_FILE}" ]]; then
  print_step "Создание резервной копии"
  BACKUP_FILE="${TARGET_FILE}.backup.$(/bin/date +%Y%m%d%H%M%S)"
  /bin/cp -p "${TARGET_FILE}" "${BACKUP_FILE}"
  print_ok "Backup создан: ${BACKUP_FILE}"
fi

print_step "Установка обновленного hosts"
/usr/bin/install -m 0644 "${TMP_FILE}" "${TARGET_FILE}"
printf '%s\n' "${REMOTE_ETAG}" > "${STATE_FILE}"

/usr/bin/dscacheutil -flushcache || true
/usr/bin/killall -HUP mDNSResponder || true

RESULT_STATUS="updated"
print_ok "Файл hosts успешно обновлен"
print_ok "Целевой файл: ${TARGET_FILE}"
log "Hosts file updated successfully from ${RAW_URL}."
