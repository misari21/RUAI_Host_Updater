# macOS Hosts Auto Updater для списка AvenCores

[English version](README.en.md)

Автоматизация для macOS, которая отслеживает обновления файла `hosts` из репозитория [AvenCores/Unlock_AI_and_EN_Services_for_Russia](https://github.com/AvenCores/Unlock_AI_and_EN_Services_for_Russia) и автоматически обновляет локальный `/private/etc/hosts` при выходе новой версии.

## Возможности

- Проверяет `source/system/etc/hosts` по `ETag`.
- Поддерживает fallback по веткам: `main` и `master`.
- Обновляет `/private/etc/hosts` только при реальном изменении.
- Перед заменой создает backup текущего `hosts`.
- После обновления очищает DNS-кэш (`dscacheutil` + `mDNSResponder`).
- Работает как системный `launchd`-daemon.
- Новый GUI без служебных маркеров `__OK__` / `__ERR__`.

## Файлы проекта

- `update-hosts.sh` - основной скрипт обновления
- `com.avencores.hosts-updater.plist` - конфигурация `launchd`
- `install.sh` - установка и запуск сервиса
- `status.sh` - показать частоту и состояние
- `remove-task.sh` - удалить только launchd-задачу (скрипт останется)
- `uninstall.sh` - удаление сервиса и скрипта
- `hosts-updater-gui.command` - user-friendly GUI-оболочка
- `build-app.sh` - сборка `.app`-оболочки

## Требования

- macOS
- `sudo` / root-доступ
- `curl`, `launchctl` (есть в macOS по умолчанию)

## Быстрый старт (без командной строки)

1. Откройте папку проекта в Finder:  
   `<PROJECT_DIR>`
2. Дважды кликните `Hosts Updater.app`  
   если файла нет, сначала один раз запустите `build-app.sh` из Terminal.
3. В главном окне нажмите большую кнопку `Установить / Исправить`.
4. Введите пароль macOS (это запрос прав администратора).
5. Дождитесь карточки `Успешно`.
6. Для проверки нажмите `Статус`:
   должно быть `Скрипт установлен: yes` и `Задача настроена: yes`.

Если macOS блокирует запуск приложения:
- откройте `Системные настройки` -> `Конфиденциальность и безопасность`;
- внизу окна разрешите запуск приложения вручную (`Open Anyway` / `Все равно открыть`).

## Установка

```bash
cd <PROJECT_DIR>
sudo ./install.sh
```

Что делает установщик:
- копирует скрипт в `/usr/local/sbin/update-avencores-hosts.sh`
- копирует plist в `/Library/LaunchDaemons/com.avencores.hosts-updater.plist`
- перезагружает и запускает daemon

## Расписание

- Label: `com.avencores.hosts-updater`
- `RunAtLoad = true`
- `StartInterval = 3600` (проверка каждый час)

## GUI (user-friendly)

Запуск через Finder: двойной клик по `hosts-updater-gui.command`.

Или через Terminal:

```bash
cd <PROJECT_DIR>
./hosts-updater-gui.command
```

Главный экран:
- основной сценарий: `Установить / Исправить` (кнопка по умолчанию)
- вторичные действия: `Статус`, `Обновить сейчас`, `Логи`, `Удалить задачу`, `Полное удаление`

UX после действий:
- короткая карточка `Успешно / Предупреждение / Ошибка`
- кнопка `Подробнее` с полным stdout/stderr
- для удаления (`Удалить задачу`, `Полное удаление`) используется двойное подтверждение

## Запуск как .app

Собрать приложение:

```bash
cd <PROJECT_DIR>
./build-app.sh
```

После сборки появится:
- `<PROJECT_DIR>/Hosts Updater.app`

Запуск:
- двойной клик по `Hosts Updater.app` в Finder.

## Ручной запуск

```bash
sudo /usr/local/sbin/update-avencores-hosts.sh
```

## Статус и частота обновления

```bash
cd <PROJECT_DIR>
sudo ./status.sh
```

Машинно-читаемый режим для GUI/скриптов:

```bash
sudo ./status.sh --brief
```

Ручные проверки:

```bash
sudo launchctl print system/com.avencores.hosts-updater
tail -n 100 /var/log/avencores-hosts-updater.log
tail -n 100 /var/log/avencores-hosts-updater.err
```

## Обновление после изменения файлов проекта

```bash
cd <PROJECT_DIR>
sudo ./install.sh
```

## Удалить только launchd-задачу

```bash
cd <PROJECT_DIR>
sudo ./remove-task.sh
```

## Удаление

```bash
cd <PROJECT_DIR>
sudo ./uninstall.sh
```

## Важно

- `/private/etc/hosts` заменяется целиком.
- Если у вас есть свои локальные записи, добавьте merge-логику в `update-hosts.sh`.
- Резервные копии сохраняются как `/private/etc/hosts.backup.YYYYmmddHHMMSS`.

## Troubleshooting

1. `Permission denied`
   Запускайте команды через `sudo`.

2. Сервис не стартует
   ```bash
   sudo plutil -lint /Library/LaunchDaemons/com.avencores.hosts-updater.plist
   ```

3. Обновления не применяются
   ```bash
   tail -n 200 /var/log/avencores-hosts-updater.err
   ```

## Disclaimer

Проект не аффилирован с AvenCores. Используйте на свой риск и проверяйте содержимое входящего `hosts` перед использованием в production.
