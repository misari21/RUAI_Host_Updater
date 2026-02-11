#!/bin/bash
set -euo pipefail

LABEL="com.avencores.hosts-updater"
PLIST="/Library/LaunchDaemons/${LABEL}.plist"

if [[ "${EUID}" -ne 0 ]]; then
  echo "[ERROR] Нужны права root. Запустите: sudo ${0}"
  exit 1
fi

echo "============================================================"
echo " Remove launchd task: ${LABEL}"
echo "============================================================"

echo "==> Остановка и выгрузка launchd-задачи"
/bin/launchctl bootout "system/${LABEL}" 2>/dev/null || true

echo "==> Удаление plist задачи"
/bin/rm -f "${PLIST}"

echo "[OK] Задача удалена"
echo "[OK] Скрипт обновления НЕ удален: /usr/local/sbin/update-avencores-hosts.sh"
echo "[OK] Чтобы вернуть задачу: sudo ./install.sh"
