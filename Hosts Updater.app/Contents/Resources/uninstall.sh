#!/bin/bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run with sudo: sudo ${0}"
  exit 1
fi

/bin/launchctl bootout system/com.avencores.hosts-updater 2>/dev/null || true
/bin/rm -f /Library/LaunchDaemons/com.avencores.hosts-updater.plist
/bin/rm -f /usr/local/sbin/update-avencores-hosts.sh

echo "Removed: com.avencores.hosts-updater"
