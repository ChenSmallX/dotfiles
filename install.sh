#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${ROOT}/scripts/lib.sh"

usage() {
  if is_en; then
    cat <<'USAGE'
Usage:
  ./install.sh             Interactive deployment
  ./install.sh --all       Deploy all modules
  ./install.sh --dry-run   Preview selected module impact without changing files
  ./install.sh --all --dry-run
                           Preview all module impact without changing files
  ./install.sh --en        Output English prompts and logs
  ./install.sh -h|--help   Show this help

Use Space to select modules and Enter to deploy in interactive mode.
Environment:
  DOTFILES_HOME            Override deployment home directory
  DOTFILES_BACKUP_DIR      Override backup directory
  DOTFILES_DRY_RUN=1       Preview changes without writing
USAGE
  else
    cat <<'USAGE'
用法：
  ./install.sh             交互式部署
  ./install.sh --all       部署所有模块
  ./install.sh --dry-run   仅预览已选择模块的影响，不修改文件
  ./install.sh --all --dry-run
                           仅预览所有模块影响，不修改文件
  ./install.sh --en        使用英文提示和日志
  ./install.sh -h|--help   显示此帮助

交互模式中使用空格选择模块，回车确认开始部署。
环境变量：
  DOTFILES_HOME            覆盖部署目标 HOME 目录
  DOTFILES_BACKUP_DIR      覆盖备份目录
  DOTFILES_DRY_RUN=1       仅预览，不写入
USAGE
  fi
}

list_modules() {
  local module
  for module in "${ROOT}"/modules/*; do
    [ -d "$module" ] || continue
    [ -x "$module/deploy.sh" ] || continue
    basename "$module"
  done | sort
}

render_menu() {
  local cursor="$3"
  clear
  msg_line "选择要部署的 dotfile 模块。空格切换选择，回车确认。" "Select dotfile modules to deploy. Space toggles, Enter confirms."
  printf '\n'
  local i mark pointer
  for i in "${!modules[@]}"; do
    mark=' '
    pointer=' '
    [ "${menu_selected[$i]}" = "1" ] && mark='x'
    [ "$i" -eq "$cursor" ] && pointer='>'
    printf '%s [%s] %s\n' "$pointer" "$mark" "${modules[$i]}"
  done
}

interactive_select() {
  local i key cursor=0

  menu_selected=()
  for i in "${!modules[@]}"; do
    menu_selected[$i]=0
  done

  while true; do
    render_menu modules menu_selected "$cursor"
    IFS= read -rsn1 key || true
    case "$key" in
      ''|$'\n'|$'\r') break ;;
      ' ')
        if [ "${menu_selected[$cursor]}" = "1" ]; then
          menu_selected[$cursor]=0
        else
          menu_selected[$cursor]=1
        fi
        ;;
      $'\033')
        IFS= read -rsn2 key || true
        case "$key" in
          '[A') [ "$cursor" -gt 0 ] && cursor=$((cursor - 1)) ;;
          '[B') [ "$cursor" -lt $((${#modules[@]} - 1)) ] && cursor=$((cursor + 1)) ;;
        esac
        ;;
      j) [ "$cursor" -lt $((${#modules[@]} - 1)) ] && cursor=$((cursor + 1)) ;;
      k) [ "$cursor" -gt 0 ] && cursor=$((cursor - 1)) ;;
    esac
  done

  selected=()
  for i in "${!modules[@]}"; do
    [ "${menu_selected[$i]}" = "1" ] && selected+=("${modules[$i]}")
  done
  return 0
}

confirm_impact() {
  local modules=("$@")
  log ""
  msg_line "部署影响：" "Deployment impact:"
  msg_line "  HOME：%s" "  home: %s" "${DOTFILES_HOME}"
  msg_line "  备份：%s" "  backup: %s" "${DOTFILES_BACKUP_DIR}"
  local module
  for module in "${modules[@]}"; do
    log ""
    log "[${module}]"
    run_module_phase "$module" describe
  done
  log ""
  if [ "$DOTFILES_DRY_RUN" = "1" ]; then
    return 0
  fi

  msg_line "按回车开始部署，或按 Ctrl-C 取消。" "Press Enter to start deployment, or Ctrl-C to cancel."
  read -r _
}

main() {
  local mode="interactive"
  local arg

  for arg in "$@"; do
    if [ "$arg" = "--en" ]; then
      DOTFILES_LANG="en"
      export DOTFILES_LANG
      break
    fi
  done

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --all) mode="all" ;;
      --dry-run)
        export DOTFILES_DRY_RUN=1
        ;;
      --en)
        DOTFILES_LANG="en"
        export DOTFILES_LANG
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        if is_en; then
          die "unknown argument: $1"
        else
          die "未知参数：$1"
        fi
        ;;
    esac
    shift
  done

  modules=()
  while IFS= read -r module; do
    modules+=("$module")
  done < <(list_modules)
  if [ "${#modules[@]}" -eq 0 ]; then
    if is_en; then
      die "no deployable modules found"
    else
      die "未找到可部署模块"
    fi
  fi
  export DOTFILES_HOME DOTFILES_BACKUP_DIR DOTFILES_DRY_RUN

  selected=()
  if [ "$mode" = "all" ]; then
    selected=("${modules[@]}")
  else
    interactive_select
  fi

  if [ "${#selected[@]}" -eq 0 ]; then
    if is_en; then
      die "no modules selected"
    else
      die "未选择任何模块"
    fi
  fi

  confirm_impact "${selected[@]}"

  if [ "$DOTFILES_DRY_RUN" = "1" ]; then
    log ""
    msg_line "预览完成。" "Dry-run completed."
    exit 0
  fi

  local module failed=0
  for module in "${selected[@]}"; do
    log ""
    msg_line "正在部署 %s..." "Deploying %s..." "${module}"
    run_module_phase "$module" deploy
  done

  log ""
  msg_line "验证结果：" "Verification:"
  for module in "${selected[@]}"; do
    log "[${module}]"
    if ! run_module_phase "$module" verify; then
      failed=1
    fi
  done

  if [ "$failed" -eq 0 ]; then
    log ""
    msg_line "部署完成。" "Deployment completed."
  else
    if is_en; then
      die "deployment completed with verification failures"
    else
      die "部署已完成，但存在验证失败"
    fi
  fi
}

main "$@"
