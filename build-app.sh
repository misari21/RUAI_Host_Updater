#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Hosts Updater.app"
APP_PATH="${SCRIPT_DIR}/${APP_NAME}"
TMP_SCRIPT="$(/usr/bin/mktemp /tmp/hosts-updater-app.XXXXXX.applescript)"

cleanup() {
  [[ -f "${TMP_SCRIPT}" ]] && /bin/rm -f "${TMP_SCRIPT}"
}
trap cleanup EXIT

cat > "${TMP_SCRIPT}" <<'OSA'
on run
  set appPath to POSIX path of (path to me)
  set appDir to do shell script "dirname " & quoted form of appPath
  set launcherPath to appDir & "/hosts-updater-gui.command"

  try
    do shell script "test -x " & quoted form of launcherPath
  on error
    display dialog "Не найден исполняемый файл:\n" & launcherPath with title "AvenCores Hosts Updater" buttons {"OK"} default button "OK" with icon stop
    return
  end try

  try
    do shell script "/bin/bash " & quoted form of launcherPath & " >/dev/null 2>&1 &"
  on error errMsg number errNum
    display dialog "Не удалось запустить GUI-скрипт.\nКод: " & errNum & "\n" & errMsg with title "AvenCores Hosts Updater" buttons {"OK"} default button "OK" with icon stop
    return
  end try
end run
OSA

/bin/rm -rf "${APP_PATH}"
/usr/bin/osacompile -o "${APP_PATH}" "${TMP_SCRIPT}"

echo "[OK] App created: ${APP_PATH}"
echo "[OK] Launch by double-clicking ${APP_NAME}"
