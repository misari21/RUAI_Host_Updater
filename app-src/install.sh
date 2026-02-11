#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_SCRIPT="${SCRIPT_DIR}/update-hosts.sh"
SOURCE_PLIST="${SCRIPT_DIR}/com.avencores.hosts-updater.plist"
TARGET_SCRIPT="/usr/local/sbin/update-avencores-hosts.sh"
TARGET_PLIST="/Library/LaunchDaemons/com.avencores.hosts-updater.plist"

if [[ "${EUID}" -ne 0 ]]; then
  echo "[ERROR] Нужны права root. Запустите: sudo ${0}"
  exit 1
fi

echo "============================================================"
echo " AvenCores Hosts Updater Installer"
echo "============================================================"
echo "==> Установка файлов updater"
/bin/mkdir -p /usr/local/sbin
/usr/bin/install -m 0755 "${SOURCE_SCRIPT}" "${TARGET_SCRIPT}"
/usr/bin/install -m 0644 "${SOURCE_PLIST}" "${TARGET_PLIST}"
echo "[OK] Файлы установлены"
echo "     script: ${TARGET_SCRIPT}"
echo "     plist : ${TARGET_PLIST}"

echo "==> Перезагрузка launchd-сервиса"
/bin/launchctl bootout system/com.avencores.hosts-updater 2>/dev/null || true
/bin/launchctl enable system/com.avencores.hosts-updater 2>/dev/null || true
/bin/launchctl bootstrap system "${TARGET_PLIST}"
/bin/launchctl enable system/com.avencores.hosts-updater 2>/dev/null || true
/bin/launchctl kickstart -k system/com.avencores.hosts-updater
echo "[OK] Сервис запущен"

echo
echo "[OK] Готово: com.avencores.hosts-updater"
echo
echo "Быстрые проверки:"
echo "  sudo launchctl print system/com.avencores.hosts-updater"
echo "  tail -n 100 /var/log/avencores-hosts-updater.log"
echo "  tail -n 100 /var/log/avencores-hosts-updater.err"
echo "  sudo /usr/local/sbin/update-avencores-hosts.sh"
