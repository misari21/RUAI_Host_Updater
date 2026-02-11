# macOS Hosts Auto Updater for AvenCores List

[Русская версия](README.ru.md)

Automation for macOS that tracks updates of the `hosts` file from [AvenCores/Unlock_AI_and_EN_Services_for_Russia](https://github.com/AvenCores/Unlock_AI_and_EN_Services_for_Russia) and updates local `/private/etc/hosts` when a new version is available.

## Features

- Checks `source/system/etc/hosts` using `ETag`.
- Supports fallback branches: `main` and `master`.
- Updates `/private/etc/hosts` only when content changes.
- Creates a backup before replacing your local `hosts`.
- Flushes DNS cache after update (`dscacheutil` + `mDNSResponder`).
- Runs as a system `launchd` daemon.
- Updated GUI without internal `__OK__` / `__ERR__` markers.

## Project files

- `update-hosts.sh` - main updater script
- `com.avencores.hosts-updater.plist` - `launchd` config
- `install.sh` - install and start service
- `status.sh` - show schedule and health status
- `remove-task.sh` - remove only launchd task (keeps updater script)
- `uninstall.sh` - remove service and script
- `hosts-updater-gui.command` - user-friendly GUI wrapper
- `build-app.sh` - build `.app` wrapper

## Requirements

- macOS
- `sudo` / root access
- `curl`, `launchctl` (default on macOS)

## Quick Start (No Command Line)

1. Open this folder in Finder:  
   `<PROJECT_DIR>`
2. Double-click `Hosts Updater.app`  
   if it is missing, run `build-app.sh` once from Terminal first.
3. In the main window, click the big `Установить / Исправить` button.
4. Enter your macOS password (administrator permission prompt).
5. Wait for the `Успешно` result card.
6. Click `Статус` to verify:
   it should show `Скрипт установлен: yes` and `Задача настроена: yes`.

If macOS blocks app launch:
- open `System Settings` -> `Privacy & Security`;
- allow the app manually (`Open Anyway`).

## Install

```bash
cd <PROJECT_DIR>
sudo ./install.sh
```

Installer actions:
- copies script to `/usr/local/sbin/update-avencores-hosts.sh`
- copies plist to `/Library/LaunchDaemons/com.avencores.hosts-updater.plist`
- reloads and starts the daemon

## Schedule

- Label: `com.avencores.hosts-updater`
- `RunAtLoad = true`
- `StartInterval = 3600` (every hour)

## GUI (user-friendly)

Launch from Finder: double-click `hosts-updater-gui.command`.

Or run from Terminal:

```bash
cd <PROJECT_DIR>
./hosts-updater-gui.command
```

Home screen:
- primary CTA: `Установить / Исправить` (default button)
- secondary actions: `Статус`, `Обновить сейчас`, `Логи`, `Удалить задачу`, `Полное удаление`

After actions:
- compact card `Success / Warning / Error`
- `Подробнее` button opens full stdout/stderr
- dangerous actions (`Удалить задачу`, `Полное удаление`) require double confirmation

## Launch as .app

Build app:

```bash
cd <PROJECT_DIR>
./build-app.sh
```

After build, you get:
- `<PROJECT_DIR>/Hosts Updater.app`

Launch:
- double-click `Hosts Updater.app` in Finder.

## Manual run

```bash
sudo /usr/local/sbin/update-avencores-hosts.sh
```

## Status and update frequency

```bash
cd <PROJECT_DIR>
sudo ./status.sh
```

Machine-readable mode for GUI/scripts:

```bash
sudo ./status.sh --brief
```

Manual checks:

```bash
sudo launchctl print system/com.avencores.hosts-updater
tail -n 100 /var/log/avencores-hosts-updater.log
tail -n 100 /var/log/avencores-hosts-updater.err
```

## Update after pulling new changes

```bash
cd <PROJECT_DIR>
sudo ./install.sh
```

## Remove only launchd task

```bash
cd <PROJECT_DIR>
sudo ./remove-task.sh
```

## Uninstall

```bash
cd <PROJECT_DIR>
sudo ./uninstall.sh
```

## Important notes

- `/private/etc/hosts` is replaced as a whole file.
- If you keep local custom entries, add merge logic to `update-hosts.sh`.
- Backups are saved as `/private/etc/hosts.backup.YYYYmmddHHMMSS`.

## Troubleshooting

1. `Permission denied`
   Run commands with `sudo`.

2. Service does not start
   ```bash
   sudo plutil -lint /Library/LaunchDaemons/com.avencores.hosts-updater.plist
   ```

3. Updates are not applied
   ```bash
   tail -n 200 /var/log/avencores-hosts-updater.err
   ```

## Disclaimer

This project is not affiliated with AvenCores. Use at your own risk and validate incoming `hosts` content before production use.
