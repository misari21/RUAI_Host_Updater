#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_DIR="${SCRIPT_DIR}/app-src"
APP_NAME="Hosts Updater.app"
APP_PATH="${SCRIPT_DIR}/${APP_NAME}"
APP_RESOURCES="${APP_PATH}/Contents/Resources"
TMP_SCRIPT=""
PAYLOAD_FILES=(
  "hosts-updater-gui.command"
  "install.sh"
  "status.sh"
  "remove-task.sh"
  "uninstall.sh"
  "update-hosts.sh"
  "com.avencores.hosts-updater.plist"
)
LAUNCH_AFTER_BUILD=1
FORCE_REBUILD=0

usage() {
  cat <<EOF
Usage: ./build-app.sh [--build-only] [--force]
  --build-only  Build/update app but do not launch it
  --force       Rebuild app even when sources are unchanged
EOF
}

for arg in "$@"; do
  case "${arg}" in
    --build-only)
      LAUNCH_AFTER_BUILD=0
      ;;
    --force)
      FORCE_REBUILD=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[ERROR] Unknown argument: ${arg}" >&2
      usage
      exit 1
      ;;
  esac
done

cleanup() {
  [[ -n "${TMP_SCRIPT}" && -f "${TMP_SCRIPT}" ]] && /bin/rm -f "${TMP_SCRIPT}"
}
create_app() {
  TMP_SCRIPT="$(/usr/bin/mktemp /tmp/hosts-updater-app.XXXXXX)"
  trap cleanup EXIT

  cat > "${TMP_SCRIPT}" <<'OSA'
on run
  set appPath to POSIX path of (path to me)
  set launcherPath to appPath & "Contents/Resources/hosts-updater-gui.command"

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

  /bin/mkdir -p "${APP_RESOURCES}"
  for file in "${PAYLOAD_FILES[@]}"; do
    /bin/cp "${SOURCE_DIR}/${file}" "${APP_RESOURCES}/${file}"
  done
  /bin/chmod 0755 \
    "${APP_RESOURCES}/hosts-updater-gui.command" \
    "${APP_RESOURCES}/install.sh" \
    "${APP_RESOURCES}/status.sh" \
    "${APP_RESOURCES}/remove-task.sh" \
    "${APP_RESOURCES}/uninstall.sh" \
    "${APP_RESOURCES}/update-hosts.sh"
  /bin/chmod 0644 "${APP_RESOURCES}/com.avencores.hosts-updater.plist"
}

for file in "${PAYLOAD_FILES[@]}"; do
  if [[ ! -f "${SOURCE_DIR}/${file}" ]]; then
    echo "[ERROR] Missing source file: ${SOURCE_DIR}/${file}" >&2
    exit 1
  fi
done

NEEDS_REBUILD="${FORCE_REBUILD}"
if [[ ! -d "${APP_PATH}" ]]; then
  NEEDS_REBUILD=1
fi
if [[ "${NEEDS_REBUILD}" -eq 0 && "${SCRIPT_DIR}/build-app.sh" -nt "${APP_PATH}" ]]; then
  NEEDS_REBUILD=1
fi
if [[ "${NEEDS_REBUILD}" -eq 0 ]]; then
  for file in "${PAYLOAD_FILES[@]}"; do
    if [[ "${SOURCE_DIR}/${file}" -nt "${APP_PATH}" ]]; then
      NEEDS_REBUILD=1
      break
    fi
  done
fi

if [[ "${NEEDS_REBUILD}" -eq 1 ]]; then
  create_app
  echo "[OK] App created: ${APP_PATH}"
else
  echo "[OK] App is up to date: ${APP_PATH}"
fi

if [[ "${LAUNCH_AFTER_BUILD}" -eq 1 ]]; then
  /usr/bin/open "${APP_PATH}"
  echo "[OK] App launched: ${APP_PATH}"
else
  echo "[OK] Build finished without launch (--build-only)."
fi
