# macOS Hosts Auto Updater (EN)

[Русская версия](README.md)

macOS automation that updates `/private/etc/hosts` from [AvenCores/Unlock_AI_and_EN_Services_for_Russia](https://github.com/AvenCores/Unlock_AI_and_EN_Services_for_Russia).

## Quick Start (No Command Line)

1. Open project folder in Finder: `<PROJECT_DIR>`
2. Double-click `Hosts Updater.app`.
3. Click `Установить / Исправить`.
4. Enter macOS admin password when prompted.
5. Open `Статус` to verify everything is configured.

If `Hosts Updater.app` is missing, build it once using `build-app.sh`.

## Quick Start (Terminal)

```bash
cd "<PROJECT_DIR>"
sudo ./install.sh
```

Check status:

```bash
cd "<PROJECT_DIR>"
sudo ./status.sh
```

## GUI Actions

- `Установить / Исправить` — install or repair service
- `Статус` — current health and schedule
- `Обновить сейчас` — run update now
- `Логи` — recent logs
- `Удалить задачу` — remove launchd task only
- `Полное удаление` — full uninstall

## Useful Commands

```bash
# Build .app
cd "<PROJECT_DIR>"
./build-app.sh

# Manual update run
sudo /usr/local/sbin/update-avencores-hosts.sh

# Machine-readable status
cd "<PROJECT_DIR>"
sudo ./status.sh --brief
```

## Project Structure

- `update-hosts.sh` - hosts updater
- `install.sh` - install and start service
- `status.sh` - service status
- `remove-task.sh` - remove task only
- `uninstall.sh` - full uninstall
- `hosts-updater-gui.command` - GUI wrapper
- `build-app.sh` - build `Hosts Updater.app`
- `com.avencores.hosts-updater.plist` - launchd config

## Important

- `/private/etc/hosts` is replaced as a whole file.
- Backup is created before replacement: `/private/etc/hosts.backup.YYYYmmddHHMMSS`.
- Admin privileges are required for install/update.

## Troubleshooting

- `Permission denied` -> run with `sudo`.
- Service won't start -> `sudo plutil -lint /Library/LaunchDaemons/com.avencores.hosts-updater.plist`
- Update/network issues -> check logs:
  - `/var/log/avencores-hosts-updater.log`
  - `/var/log/avencores-hosts-updater.err`
