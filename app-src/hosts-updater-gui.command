#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RUN_EXIT=1
RUN_STDOUT=""
RUN_STDERR=""

trim_multiline() {
  local text="$1"
  local max_lines="${2:-12}"
  /usr/bin/printf '%s\n' "$text" | /usr/bin/awk -v max="${max_lines}" 'NF {print; c++; if (c>=max) exit}'
}

kv_value() {
  local text="$1"
  local key="$2"
  /usr/bin/printf '%s\n' "$text" | /usr/bin/awk -F'=' -v k="$key" '$1==k {print substr($0, index($0, "=")+1); exit}'
}

normalize_newlines() {
  /usr/bin/perl -0777 -pe 's/\r\n?/\n/g'
}

run_command() {
  local cmd="$1"
  local admin="$2"
  local raw=""
  local clean=""

  raw="$(/usr/bin/osascript - "$cmd" "$admin" <<'OSA'
on run argv
  set cmd to item 1 of argv
  set needAdmin to item 2 of argv

  set wrapped to "OUT=$(mktemp); (" & cmd & ") >\"$OUT\" 2>&1; CODE=$?; " & ¬
    "echo __OUT_BEGIN__; cat \"$OUT\"; echo __OUT_END__; " & ¬
    "echo __EXIT_CODE__=$CODE; rm -f \"$OUT\"; exit 0"

  try
    if needAdmin is "yes" then
      return do shell script "/bin/bash -lc " & quoted form of wrapped with administrator privileges
    else
      return do shell script "/bin/bash -lc " & quoted form of wrapped
    end if
  on error errMsg number errNum
    return "__OUT_BEGIN__\n__OUT_END__\n__EXIT_CODE__=1\n__AS_ERROR__=" & errNum & ":" & errMsg
  end try
end run
OSA
)"

  clean="$(/usr/bin/printf '%s' "$raw" | normalize_newlines)"

  RUN_EXIT="$(/usr/bin/perl -0777 -ne 'if(/__EXIT_CODE__=(\d+)/s){print $1; exit}' <<<"$clean")"
  RUN_STDOUT="$(/usr/bin/perl -0777 -ne 'if(/__OUT_BEGIN__\n(.*?)\n__OUT_END__/s){print $1; exit}' <<<"$clean")"
  RUN_STDERR="$(/usr/bin/perl -0777 -ne 'if(/__AS_ERROR__=(.*)$/s){print $1; exit}' <<<"$clean")"

  if [[ -z "${RUN_EXIT}" ]]; then
    RUN_EXIT=1
    RUN_STDERR="Не удалось распознать результат выполнения."
  fi

  if [[ "${RUN_EXIT}" != "0" && -z "${RUN_STDOUT}" && -z "${RUN_STDERR}" ]]; then
    RUN_STDERR="Команда завершилась с ошибкой без вывода."
  fi
}

show_details() {
  local title="$1"
  local body="$2"
  [[ -n "$body" ]] || body="(подробности отсутствуют)"

  /usr/bin/osascript - "$title" "$body" <<'OSA'
on run argv
  set titleText to item 1 of argv
  set bodyText to item 2 of argv
  if (length of bodyText) > 12000 then
    set bodyText to text 1 thru 12000 of bodyText & "\n... (обрезано)"
  end if
  display dialog bodyText with title titleText with icon note buttons {"OK"} default button "OK" giving up after 120
end run
OSA
}

show_card() {
  local status="$1"
  local summary="$2"
  local details="$3"
  local action="$4"
  local clicked=""

  clicked="$(/usr/bin/osascript - "$status" "$summary" <<'OSA'
on run argv
  set statusText to item 1 of argv
  set summaryText to item 2 of argv
  if (length of summaryText) > 2800 then
    set summaryText to text 1 thru 2800 of summaryText & "\n... (обрезано)"
  end if
  set d to display dialog summaryText with title ("AvenCores Hosts Updater — " & statusText) with icon note buttons {"OK", "Подробнее"} default button "OK" giving up after 90
  return button returned of d
end run
OSA
)"

  if [[ "${clicked}" == "Подробнее" ]]; then
    show_details "${action}: подробный вывод" "$details"
  fi
}

confirm_danger() {
  local action="$1"
  local p1 p2

  p1="$(/usr/bin/osascript - "$action" <<'OSA'
on run argv
  set actionText to item 1 of argv
  set d to display dialog ("Вы уверены, что хотите выполнить: " & actionText & "?") with title "Подтверждение" with icon caution buttons {"Отмена", "Продолжить"} default button "Отмена"
  return button returned of d
end run
OSA
)"
  [[ "$p1" == "Продолжить" ]] || return 1

  p2="$(/usr/bin/osascript - "$action" <<'OSA'
on run argv
  set actionText to item 1 of argv
  set d to display dialog ("Подтвердите действие: " & actionText & "\nЭто действие можно отменить только вручную.") with title "Финальное подтверждение" with icon stop buttons {"Нет", "Да, удалить"} default button "Нет"
  return button returned of d
end run
OSA
)"

  [[ "$p2" == "Да, удалить" ]]
}

build_health_summary() {
  run_command "cd '${SCRIPT_DIR}' && ./status.sh --brief" "yes"

  local b="$RUN_STDOUT"
  local installed task state interval runat runs lastexit etag
  installed="$(kv_value "$b" "installed_script")"
  task="$(kv_value "$b" "task_configured")"
  state="$(kv_value "$b" "service_state")"
  interval="$(kv_value "$b" "interval_sec")"
  runat="$(kv_value "$b" "run_at_load")"
  runs="$(kv_value "$b" "runs")"
  lastexit="$(kv_value "$b" "last_exit")"
  etag="$(kv_value "$b" "etag")"

  [[ -n "$installed" ]] || installed="unknown"
  [[ -n "$task" ]] || task="unknown"
  [[ -n "$state" ]] || state="unknown"
  [[ -n "$interval" ]] || interval="unknown"
  [[ -n "$runat" ]] || runat="unknown"
  [[ -n "$runs" ]] || runs="unknown"
  [[ -n "$lastexit" ]] || lastexit="unknown"
  [[ -n "$etag" ]] || etag="-"

  /bin/cat <<TXT
Главный сценарий: Установить / Исправить

Текущее состояние:
• Скрипт установлен: ${installed}
• Задача настроена: ${task}
• Состояние launchd: ${state}
• Частота: ${interval} сек
• RunAtLoad: ${runat}
• Runs: ${runs}
• Last exit: ${lastexit}
• ETag: ${etag}
TXT
}

choose_action() {
  local prompt="$1"
  /usr/bin/osascript - "$prompt" <<'OSA'
on run argv
  set promptText to item 1 of argv
  set itemsList to {"Установить / Исправить", "Статус", "Обновить сейчас", "Логи", "Удалить задачу", "Полное удаление", "Открыть папку проекта", "Выход"}
  set selected to choose from list itemsList with title "AvenCores Hosts Updater" with prompt promptText default items {"Установить / Исправить"}
  if selected is false then return "Выход"
  return item 1 of selected
end run
OSA
}

build_details() {
  /bin/cat <<TXT
stdout:
${RUN_STDOUT}

stderr:
${RUN_STDERR}
TXT
}

action_install() {
  run_command "cd '${SCRIPT_DIR}' && ./install.sh" "yes"
  local status="Успешно"
  local summary="Установка/исправление завершено."
  [[ "$RUN_EXIT" == "0" ]] || { status="Ошибка"; summary="Не удалось выполнить установку/исправление."; }

  summary=$(/bin/cat <<TXT
${summary}

$(trim_multiline "$RUN_STDOUT" 8)
TXT
)
  show_card "$status" "$summary" "$(build_details)" "Установить / Исправить"
}

action_status() {
  run_command "cd '${SCRIPT_DIR}' && ./status.sh --brief" "yes"
  local brief="$RUN_STDOUT"
  local installed task state interval runat runs lastexit etag
  installed="$(kv_value "$brief" "installed_script")"
  task="$(kv_value "$brief" "task_configured")"
  state="$(kv_value "$brief" "service_state")"
  interval="$(kv_value "$brief" "interval_sec")"
  runat="$(kv_value "$brief" "run_at_load")"
  runs="$(kv_value "$brief" "runs")"
  lastexit="$(kv_value "$brief" "last_exit")"
  etag="$(kv_value "$brief" "etag")"

  [[ -n "$installed" ]] || installed="unknown"
  [[ -n "$task" ]] || task="unknown"
  [[ -n "$state" ]] || state="unknown"
  [[ -n "$interval" ]] || interval="unknown"
  [[ -n "$runat" ]] || runat="unknown"
  [[ -n "$runs" ]] || runs="unknown"
  [[ -n "$lastexit" ]] || lastexit="unknown"
  [[ -n "$etag" ]] || etag="-"

  run_command "cd '${SCRIPT_DIR}' && ./status.sh" "yes"
  local full="$RUN_STDOUT"
  local full_err="$RUN_STDERR"

  local status="Успешно"
  [[ "$installed" == "yes" && "$task" == "yes" ]] || status="Предупреждение"

  local summary details
  summary=$(/bin/cat <<TXT
Статус сервиса:
• Скрипт установлен: ${installed}
• Задача настроена: ${task}
• Состояние launchd: ${state}
• Частота: ${interval} сек
• RunAtLoad: ${runat}
• Runs: ${runs}
• Last exit: ${lastexit}
• ETag: ${etag}
TXT
)
  details=$(/bin/cat <<TXT
-- brief --
${brief}

-- full stdout --
${full}

-- full stderr --
${full_err}
TXT
)

  show_card "$status" "$summary" "$details" "Статус"
}

action_update_now() {
  run_command "cd '${SCRIPT_DIR}' && ./update-hosts.sh" "yes"
  local status="Успешно"
  local summary="Обновление выполнено."

  if /usr/bin/printf '%s\n' "$RUN_STDOUT" | /usr/bin/grep -qi "не требуется"; then
    summary="Обновление не требуется: файл уже актуален."
  elif /usr/bin/printf '%s\n' "$RUN_STDOUT" | /usr/bin/grep -qi "успешно обновлен"; then
    summary="Файл hosts обновлен успешно."
  elif /usr/bin/printf '%s\n' "$RUN_STDOUT" | /usr/bin/grep -qi "уже выполняется"; then
    status="Предупреждение"
    summary="Обновление пропущено: процесс уже выполняется."
  fi

  [[ "$RUN_EXIT" == "0" ]] || { status="Ошибка"; summary="Обновление завершилось с ошибкой."; }

  summary=$(/bin/cat <<TXT
${summary}

$(trim_multiline "$RUN_STDOUT" 8)
TXT
)
  show_card "$status" "$summary" "$(build_details)" "Обновить сейчас"
}

action_logs() {
  run_command "tail -n 40 /var/log/avencores-hosts-updater.log; echo '-----'; tail -n 40 /var/log/avencores-hosts-updater.err" "yes"
  local status="Успешно"
  local summary="Показаны последние логи."
  [[ "$RUN_EXIT" == "0" ]] || { status="Ошибка"; summary="Не удалось прочитать логи."; }

  summary=$(/bin/cat <<TXT
${summary}

$(trim_multiline "$RUN_STDOUT" 10)
TXT
)
  show_card "$status" "$summary" "$(build_details)" "Логи"
}

action_remove_task() {
  if ! confirm_danger "Удалить только launchd-задачу"; then
    show_card "Предупреждение" "Действие отменено пользователем." "Пользователь отменил удаление задачи." "Удалить задачу"
    return
  fi

  run_command "cd '${SCRIPT_DIR}' && ./remove-task.sh" "yes"
  local status="Успешно"
  local summary="Launchd-задача удалена. Скрипт обновления оставлен."
  [[ "$RUN_EXIT" == "0" ]] || { status="Ошибка"; summary="Не удалось удалить launchd-задачу."; }

  summary=$(/bin/cat <<TXT
${summary}

$(trim_multiline "$RUN_STDOUT" 8)
TXT
)
  show_card "$status" "$summary" "$(build_details)" "Удалить задачу"
}

action_uninstall() {
  if ! confirm_danger "Полное удаление"; then
    show_card "Предупреждение" "Действие отменено пользователем." "Пользователь отменил полное удаление." "Полное удаление"
    return
  fi

  run_command "cd '${SCRIPT_DIR}' && ./uninstall.sh" "yes"
  local status="Успешно"
  local summary="Выполнено полное удаление (задача + скрипт)."
  [[ "$RUN_EXIT" == "0" ]] || { status="Ошибка"; summary="Не удалось выполнить полное удаление."; }

  summary=$(/bin/cat <<TXT
${summary}

$(trim_multiline "$RUN_STDOUT" 8)
TXT
)
  show_card "$status" "$summary" "$(build_details)" "Полное удаление"
}

open_project_folder() {
  /usr/bin/open "${SCRIPT_DIR}"
  local summary
  summary=$(/bin/cat <<TXT
Папка проекта открыта.
${SCRIPT_DIR}
TXT
)
  show_card "Успешно" "$summary" "Папка проекта открыта: ${SCRIPT_DIR}" "Открыть папку проекта"
}

main() {
  while true; do
    local action
    action="$(choose_action "$(build_health_summary)")"

    case "$action" in
      "Установить / Исправить") action_install ;;
      "Статус") action_status ;;
      "Обновить сейчас") action_update_now ;;
      "Логи") action_logs ;;
      "Удалить задачу") action_remove_task ;;
      "Полное удаление") action_uninstall ;;
      "Открыть папку проекта") open_project_folder ;;
      "Выход") break ;;
      *) show_card "Ошибка" "Неизвестное действие: $action" "Неизвестное действие: $action" "Ошибка" ;;
    esac
  done
}

main
