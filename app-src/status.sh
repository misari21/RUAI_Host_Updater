#!/bin/bash
set -euo pipefail

LABEL="com.avencores.hosts-updater"
PLIST="/Library/LaunchDaemons/${LABEL}.plist"
SCRIPT="/usr/local/sbin/update-avencores-hosts.sh"
LOG_FILE="/var/log/avencores-hosts-updater.log"
ERR_FILE="/var/log/avencores-hosts-updater.err"
STATE_FILE="/var/db/avencores-hosts-updater/last_etag"

BRIEF_MODE=0
if [[ "${1:-}" == "--brief" || "${HOSTS_UPDATER_BRIEF:-0}" == "1" ]]; then
  BRIEF_MODE=1
fi

if [[ "${EUID}" -ne 0 ]]; then
  echo "[ERROR] Нужны права root. Запустите: sudo ${0}"
  exit 1
fi

TASK_CONFIGURED="no"
INSTALLED_SCRIPT="no"
INTERVAL="unknown"
RUN_AT_LOAD="unknown"
STATE="unknown"
RUNS="unknown"
LAST_EXIT="unknown"
RUN_INTERVAL="unknown"
ETAG=""

if [[ -f "${PLIST}" ]]; then
  TASK_CONFIGURED="yes"
fi

if [[ -f "${SCRIPT}" ]]; then
  INSTALLED_SCRIPT="yes"
fi

if [[ "${TASK_CONFIGURED}" == "yes" ]]; then
  INTERVAL="$(/usr/libexec/PlistBuddy -c 'Print :StartInterval' "${PLIST}" 2>/dev/null || echo "unknown")"
  RUN_AT_LOAD="$(/usr/libexec/PlistBuddy -c 'Print :RunAtLoad' "${PLIST}" 2>/dev/null || echo "unknown")"

  PRINT_OUT="$(/bin/launchctl print "system/${LABEL}" 2>&1 || true)"
  STATE="$(/bin/echo "${PRINT_OUT}" | /usr/bin/awk -F'= ' '/state = / {print $2; exit}')"
  RUNS="$(/bin/echo "${PRINT_OUT}" | /usr/bin/awk -F'= ' '/runs = / {print $2; exit}')"
  LAST_EXIT="$(/bin/echo "${PRINT_OUT}" | /usr/bin/awk -F'= ' '/last exit code = / {print $2; exit}')"
  RUN_INTERVAL="$(/bin/echo "${PRINT_OUT}" | /usr/bin/awk -F'= ' '/run interval = / {print $2; exit}')"

  [[ -n "${STATE}" ]] || STATE="unknown"
  [[ -n "${RUNS}" ]] || RUNS="unknown"
  [[ -n "${LAST_EXIT}" ]] || LAST_EXIT="unknown"
  [[ -n "${RUN_INTERVAL}" ]] || RUN_INTERVAL="unknown"
fi

if [[ -f "${STATE_FILE}" ]]; then
  ETAG="$(/bin/cat "${STATE_FILE}")"
fi

if [[ "${BRIEF_MODE}" == "1" ]]; then
  echo "installed_script=${INSTALLED_SCRIPT}"
  echo "task_configured=${TASK_CONFIGURED}"
  echo "interval_sec=${INTERVAL}"
  echo "run_at_load=${RUN_AT_LOAD}"
  echo "service_state=${STATE}"
  echo "runs=${RUNS}"
  echo "last_exit=${LAST_EXIT}"
  echo "run_interval=${RUN_INTERVAL}"
  echo "etag=${ETAG}"
  exit 0
fi

echo "============================================================"
echo " AvenCores Hosts Updater Status"
echo "============================================================"

if [[ "${TASK_CONFIGURED}" == "no" ]]; then
  echo "[WARN] Задача launchd не установлена: ${PLIST}"
  echo "       Установите: sudo ./install.sh"
  exit 0
fi

if [[ "${INSTALLED_SCRIPT}" == "yes" ]]; then
  echo "[OK] Скрипт установлен: ${SCRIPT}"
else
  echo "[WARN] Скрипт не найден: ${SCRIPT}"
fi

if [[ "${INTERVAL}" != "unknown" ]]; then
  echo "[OK] Частота проверки: каждые ${INTERVAL} сек (~$((INTERVAL / 60)) мин)"
else
  echo "[WARN] Не удалось определить StartInterval в plist"
fi

echo "[OK] RunAtLoad: ${RUN_AT_LOAD}"

if [[ "${STATE}" != "unknown" ]]; then
  echo "[OK] Состояние launchd: ${STATE}"
else
  echo "[WARN] Не удалось получить состояние launchd"
fi

if [[ "${RUNS}" != "unknown" ]]; then
  echo "[OK] Количество запусков: ${RUNS}"
fi

if [[ "${LAST_EXIT}" != "unknown" ]]; then
  if [[ "${LAST_EXIT}" == "0" ]]; then
    echo "[OK] Последний код выхода: 0"
  else
    echo "[WARN] Последний код выхода: ${LAST_EXIT}"
  fi
fi

if [[ "${RUN_INTERVAL}" != "unknown" ]]; then
  echo "[OK] Интервал из launchd: ${RUN_INTERVAL}"
fi

if [[ -n "${ETAG}" ]]; then
  echo "[OK] Последний сохраненный ETag: ${ETAG}"
else
  echo "[WARN] ETag state файл еще не создан: ${STATE_FILE}"
fi

echo "------------------------------------------------------------"
echo "Последние логи (log):"
if [[ -f "${LOG_FILE}" ]]; then
  /usr/bin/tail -n 5 "${LOG_FILE}"
else
  echo "(файл отсутствует: ${LOG_FILE})"
fi

echo "------------------------------------------------------------"
echo "Последние логи (err):"
if [[ -f "${ERR_FILE}" ]]; then
  /usr/bin/tail -n 5 "${ERR_FILE}"
else
  echo "(файл отсутствует: ${ERR_FILE})"
fi

echo "------------------------------------------------------------"
echo "Проверка вручную: sudo /usr/local/sbin/update-avencores-hosts.sh"
