#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RUN_EXIT=1
RUN_STDOUT=""
RUN_STDERR=""

trim_multiline() {
  local text="$1"
  local max_lines="${2:-14}"
  /bin/echo "$text" | /usr/bin/awk -v max="${max_lines}" 'NF {print; c++; if (c>=max) exit}'
}

brief_value() {
  local text="$1"
  local key="$2"
  /bin/echo "$text" | /usr/bin/awk -F'=' -v k="$key" '$1==k {sub(/^[^=]*=/, "", $0); print; exit}'
}

run_command() {
  local cmd="$1"
  local admin="$2"
  local raw=""
  local raw_clean=""

  raw="$(/usr/bin/osascript - "$cmd" "$admin" <<'OSA'
on run argv
  set cmd to item 1 of argv
  set needAdmin to item 2 of argv

  set wrapped to "TMP_OUT=$(mktemp); (" & cmd & ") >\"$TMP_OUT\" 2>&1; CODE=$?; " & ¬
    "echo __OUT_BEGIN__; cat \"$TMP_OUT\"; echo __OUT_END__; " & ¬
    "echo __EXIT_CODE__=$CODE; rm -f \"$TMP_OUT\"; exit 0"

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

  # osascript may return CR-separated lines; convert CR to LF, then parse robustly.
  raw_clean="$(/usr/bin/perl -0777 -pe 's/\r/\n/g' <<<"$raw")"

  RUN_EXIT="$(/usr/bin/perl -0777 -ne 'if(/EXIT_CODE[^=]*=(\d+)/s){print $1; exit}' <<<"$raw_clean")"
  RUN_STDOUT="$(/usr/bin/perl -0777 -ne 'if(/OUT_BEGIN[^\n]*\n(.*?)\n[^\n]*OUT_END/s){print $1; exit}' <<<"$raw_clean")"
  RUN_STDERR="$(/usr/bin/perl -0777 -ne 'if(/AS_ERROR=(.*)$/s){print $1; exit}' <<<"$raw_clean")"

  # Fallback for edge formatting where EXIT_CODE appears but with unusual separators.
  if [[ -z "${RUN_EXIT}" ]]; then
    RUN_EXIT="$(/usr/bin/grep -Eo 'EXIT_CODE[^=]*=[0-9]+' <<<"$raw_clean" | /usr/bin/tail -n 1 | /usr/bin/awk -F'=' '{print $2}')"
  fi

  if [[ -z "${RUN_EXIT}" ]]; then
    RUN_EXIT=1
    RUN_STDERR="Не удалось распознать результат выполнения. Raw output:
${raw}"
  fi

  if [[ "${RUN_EXIT}" != "0" && -z "${RUN_STDOUT}" && -z "${RUN_STDERR}" ]]; then
    RUN_STDERR="Команда завершилась с ошибкой без вывода. CMD: ${cmd}"
  fi
}

show_details() {
  local header="$1"
  local details="$2"
  if [[ -z "${details}" ]]; then
    details="(подробности отсутствуют)"
  fi

  /usr/bin/osascript - "$header" "$details" <<'OSA'
on run argv
  set header to item 1 of argv
  set body to item 2 of argv
  if (length of body) > 12000 then
    set body to text 1 thru 12000 of body & "\n... (обрезано)"
  end if
  display dialog body with title header with icon note buttons {"OK"} default button "OK" giving up after 120
end run
OSA
}

show_card() {
  local status="$1"
  local summary="$2"
  local details="$3"
  local action_title="$4"
  local clicked=""

  clicked="$(/usr/bin/osascript - "$status" "$summary" <<'OSA'
on run argv
  set status to item 1 of argv
  set summary to item 2 of argv
  if (length of summary) > 2500 then
    set summary to text 1 thru 2500 of summary & "\n... (обрезано)"
  end if
  set d to display dialog summary with title ("AvenCores Hosts Updater — " & status) with icon note buttons {"OK", "Подробнее"} default button "OK" giving up after 90
  return button returned of d
end run
OSA
)"

  if [[ "${clicked}" == "Подробнее" ]]; then
    show_details "${action_title}: подробный вывод" "${details}"
  fi
}

confirm_danger() {
  local action_name="$1"
  local phase1=""
  local phase2=""

  phase1="$(/usr/bin/osascript - "$action_name" <<'OSA'
on run argv
  set actionName to item 1 of argv
  set d to display dialog ("Вы уверены, что хотите выполнить: " & actionName & "?") with title "Подтверждение" with icon caution buttons {"Отмена", "Продолжить"} default button "Отмена"
  return button returned of d
end run
OSA
)"
  [[ "${phase1}" == "Продолжить" ]] || return 1

  phase2="$(/usr/bin/osascript - "$action_name" <<'OSA'
on run argv
  set actionName to item 1 of argv
  set d to display dialog ("Подтвердите действие: " & actionName & "\nЭто изменение можно отменить только вручную.") with title "Финальное подтверждение" with icon stop buttons {"Нет", "Да, удалить"} default button "Нет"
  return button returned of d
end run
OSA
)"

  [[ "${phase2}" == "Да, удалить" ]]
}

build_health_summary() {
  run_command "cd '${SCRIPT_DIR}' && ./status.sh --brief" "yes"

  local b="${RUN_STDOUT}"
  local installed task interval runat runs lastexit etag state
  installed="$(brief_value "$b" "installed_script")"
  task="$(brief_value "$b" "task_configured")"
  interval="$(brief_value "$b" "interval_sec")"
  runat="$(brief_value "$b" "run_at_load")"
  runs="$(brief_value "$b" "runs")"
  lastexit="$(brief_value "$b" "last_exit")"
  etag="$(brief_value "$b" "etag")"
  state="$(brief_value "$b" "service_state")"

  [[ -n "$installed" ]] || installed="unknown"
  [[ -n "$task" ]] || task="unknown"
  [[ -n "$interval" ]] || interval="unknown"
  [[ -n "$runat" ]] || runat="unknown"
  [[ -n "$runs" ]] || runs="unknown"
  [[ -n "$lastexit" ]] || lastexit="unknown"
  [[ -n "$etag" ]] || etag="-"
  [[ -n "$state" ]] || state="unknown"

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
  if selected is false then
    return "Выход"
  end if
  return item 1 of selected
end run
OSA
}

open_project_folder() {
  /usr/bin/open "${SCRIPT_DIR}"
  local summary
  summary=$(/bin/cat <<TXT
Папка проекта открыта.
${SCRIPT_DIR}
TXT
)
  show_card "Успешно" "${summary}" "Папка проекта открыта: ${SCRIPT_DIR}" "Открыть папку проекта"
}

render_status_card() {
  run_command "cd '${SCRIPT_DIR}' && ./status.sh --brief" "yes"
  local brief="${RUN_STDOUT}"
  local brief_err="${RUN_STDERR}"

  local installed task interval runat runs lastexit etag state
  installed="$(brief_value "$brief" "installed_script")"
  task="$(brief_value "$brief" "task_configured")"
  interval="$(brief_value "$brief" "interval_sec")"
  runat="$(brief_value "$brief" "run_at_load")"
  runs="$(brief_value "$brief" "runs")"
  lastexit="$(brief_value "$brief" "last_exit")"
  etag="$(brief_value "$brief" "etag")"
  state="$(brief_value "$brief" "service_state")"

  [[ -n "$installed" ]] || installed="unknown"
  [[ -n "$task" ]] || task="unknown"
  [[ -n "$interval" ]] || interval="unknown"
  [[ -n "$runat" ]] || runat="unknown"
  [[ -n "$runs" ]] || runs="unknown"
  [[ -n "$lastexit" ]] || lastexit="unknown"
  [[ -n "$etag" ]] || etag="-"
  [[ -n "$state" ]] || state="unknown"

  run_command "cd '${SCRIPT_DIR}' && ./status.sh" "yes"
  local full_status="${RUN_STDOUT}"
  local full_err="${RUN_STDERR}"

  local summary details status_label
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
-- brief stdout --
${brief}

-- brief stderr --
${brief_err}

-- full status stdout --
${full_status}

-- full status stderr --
${full_err}
TXT
)

  status_label="Успешно"
  if [[ "${task}" != "yes" || "${installed}" != "yes" ]]; then
    status_label="Предупреждение"
  fi

  show_card "${status_label}" "${summary}" "${details}" "Статус"
}

action_install() {
  run_command "cd '${SCRIPT_DIR}' && ./install.sh" "yes"

  local status_label summary extra details
  status_label="Успешно"
  summary="Установка/исправление завершено."
  extra="$(trim_multiline "${RUN_STDOUT}" 8)"

  if [[ "${RUN_EXIT}" != "0" ]]; then
    status_label="Ошибка"
    summary="Не удалось выполнить установку/исправление."
  fi

  summary=$(/bin/cat <<TXT
${summary}

${extra}
TXT
)
  details=$(/bin/cat <<TXT
stdout:
${RUN_STDOUT}

stderr:
${RUN_STDERR}
TXT
)

  show_card "${status_label}" "${summary}" "${details}" "Установить / Исправить"
}

action_update_now() {
  run_command "cd '${SCRIPT_DIR}' && ./update-hosts.sh" "yes"

  local status_label summary compact details
  status_label="Успешно"
  summary="Обновление выполнено."

  if /bin/echo "${RUN_STDOUT}" | /usr/bin/grep -qi "не требуется"; then
    summary="Обновление не требуется: файл уже актуален."
  elif /bin/echo "${RUN_STDOUT}" | /usr/bin/grep -qi "успешно обновлен"; then
    summary="Файл hosts обновлен успешно."
  elif /bin/echo "${RUN_STDOUT}" | /usr/bin/grep -qi "уже выполняется"; then
    status_label="Предупреждение"
    summary="Обновление пропущено: процесс уже выполняется."
  fi

  if [[ "${RUN_EXIT}" != "0" ]]; then
    status_label="Ошибка"
    summary="Обновление завершилось с ошибкой."
  fi

  compact="$(trim_multiline "${RUN_STDOUT}" 8)"
  summary=$(/bin/cat <<TXT
${summary}

${compact}
TXT
)
  details=$(/bin/cat <<TXT
stdout:
${RUN_STDOUT}

stderr:
${RUN_STDERR}
TXT
)

  show_card "${status_label}" "${summary}" "${details}" "Обновить сейчас"
}

action_logs() {
  run_command "tail -n 40 /var/log/avencores-hosts-updater.log; echo '-----'; tail -n 40 /var/log/avencores-hosts-updater.err" "yes"

  local status_label summary compact details
  status_label="Успешно"
  summary="Показаны последние логи."

  if [[ "${RUN_EXIT}" != "0" ]]; then
    status_label="Ошибка"
    summary="Не удалось прочитать логи."
  fi

  compact="$(trim_multiline "${RUN_STDOUT}" 10)"
  summary=$(/bin/cat <<TXT
${summary}

${compact}
TXT
)
  details=$(/bin/cat <<TXT
stdout:
${RUN_STDOUT}

stderr:
${RUN_STDERR}
TXT
)

  show_card "${status_label}" "${summary}" "${details}" "Логи"
}

action_remove_task() {
  if ! confirm_danger "Удалить только launchd-задачу"; then
    show_card "Предупреждение" "Действие отменено пользователем." "Пользователь отменил удаление задачи." "Удалить задачу"
    return
  fi

  run_command "cd '${SCRIPT_DIR}' && ./remove-task.sh" "yes"

  local status_label summary compact details
  status_label="Успешно"
  summary="Launchd-задача удалена. Скрипт обновления оставлен."

  if [[ "${RUN_EXIT}" != "0" ]]; then
    status_label="Ошибка"
    summary="Не удалось удалить launchd-задачу."
  fi

  compact="$(trim_multiline "${RUN_STDOUT}" 8)"
  summary=$(/bin/cat <<TXT
${summary}

${compact}
TXT
)
  details=$(/bin/cat <<TXT
stdout:
${RUN_STDOUT}

stderr:
${RUN_STDERR}
TXT
)

  show_card "${status_label}" "${summary}" "${details}" "Удалить задачу"
}

action_uninstall() {
  if ! confirm_danger "Полное удаление"; then
    show_card "Предупреждение" "Действие отменено пользователем." "Пользователь отменил полное удаление." "Полное удаление"
    return
  fi

  run_command "cd '${SCRIPT_DIR}' && ./uninstall.sh" "yes"

  local status_label summary compact details
  status_label="Успешно"
  summary="Выполнено полное удаление (задача + скрипт)."

  if [[ "${RUN_EXIT}" != "0" ]]; then
    status_label="Ошибка"
    summary="Не удалось выполнить полное удаление."
  fi

  compact="$(trim_multiline "${RUN_STDOUT}" 8)"
  summary=$(/bin/cat <<TXT
${summary}

${compact}
TXT
)
  details=$(/bin/cat <<TXT
stdout:
${RUN_STDOUT}

stderr:
${RUN_STDERR}
TXT
)

  show_card "${status_label}" "${summary}" "${details}" "Полное удаление"
}

main_loop() {
  while true; do
    local home_text action
    home_text="$(build_health_summary)"
    action="$(choose_action "${home_text}")"

    case "${action}" in
      "Установить / Исправить")
        action_install
        ;;
      "Статус")
        render_status_card
        ;;
      "Обновить сейчас")
        action_update_now
        ;;
      "Логи")
        action_logs
        ;;
      "Удалить задачу")
        action_remove_task
        ;;
      "Полное удаление")
        action_uninstall
        ;;
      "Открыть папку проекта")
        open_project_folder
        ;;
      "Выход")
        break
        ;;
      *)
        show_card "Ошибка" "Неизвестное действие: ${action}" "Неизвестное действие: ${action}" "Ошибка"
        ;;
    esac
  done
}

main_loop
