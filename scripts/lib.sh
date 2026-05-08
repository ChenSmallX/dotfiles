#!/usr/bin/env bash

set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOTFILES_HOME="${DOTFILES_HOME:-$HOME}"
DOTFILES_BACKUP_DIR="${DOTFILES_BACKUP_DIR:-${DOTFILES_HOME}/.dotfiles-backup/$(date +%Y%m%d%H%M%S)}"
DOTFILES_DRY_RUN="${DOTFILES_DRY_RUN:-0}"
DOTFILES_LANG="${DOTFILES_LANG:-zh}"

log() {
  printf '%s\n' "$*"
}

is_en() {
  [ "${DOTFILES_LANG}" = "en" ]
}

parse_language_arg() {
  if [ "${1:-}" = "--en" ]; then
    DOTFILES_LANG="en"
    export DOTFILES_LANG
    return 0
  fi
  return 1
}

msg() {
  local zh="$1"
  local en="$2"
  shift 2
  if is_en; then
    printf "$en" "$@"
  else
    printf "$zh" "$@"
  fi
}

msg_line() {
  msg "$@"
  printf '\n'
}

die() {
  if is_en; then
    printf 'ERROR: %s\n' "$*" >&2
  else
    printf '错误：%s\n' "$*" >&2
  fi
  exit 1
}

is_windows_like() {
  case "$(uname -s 2>/dev/null || printf unknown)" in
    MINGW*|MSYS*|CYGWIN*) return 0 ;;
    *) return 1 ;;
  esac
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

find_install_command() {
  if command_exists apt; then
    printf 'sudo apt install -y'
  elif command_exists yum; then
    printf 'sudo yum install -y'
  elif command_exists dnf; then
    printf 'sudo dnf install -y'
  elif command_exists brew; then
    printf 'brew install'
  else
    return 1
  fi
}

ensure_tools() {
  local missing=()
  local tool

  for tool in "$@"; do
    if ! command_exists "$tool"; then
      missing+=("$tool")
    fi
  done

  if [ "${#missing[@]}" -eq 0 ]; then
    msg_line "必需工具已满足：%s" "Required tools satisfied: %s" "$*"
    return 0
  fi

  msg_line "缺少必需工具：%s" "Missing required tools: %s" "${missing[*]}"
  if [ "$DOTFILES_DRY_RUN" = "1" ]; then
    msg_line "预览模式：跳过工具安装。" "Dry-run mode: skipping tool installation."
    return 0
  fi

  local install_cmd
  if install_cmd="$(find_install_command)"; then
    msg_line "现在安装它们？%s %s" "Install them now? %s %s" "$install_cmd" "${missing[*]}"
    msg_line "按回车继续，或按 Ctrl-C 取消。" "Press Enter to continue, or Ctrl-C to cancel."
    read -r _
    # shellcheck disable=SC2086
    ${install_cmd} "${missing[@]}"
  else
    if is_en; then
      die "No supported package manager found. Install manually: ${missing[*]}"
    else
      die "未找到支持的包管理器。请手动安装：${missing[*]}"
    fi
  fi
}

backup_existing_target() {
  local target="$1"
  local rel="${target#"$DOTFILES_HOME"/}"
  local backup="${DOTFILES_BACKUP_DIR}/${rel}"

  if [ "$DOTFILES_DRY_RUN" = "1" ]; then
    msg_line "  将备份：%s -> %s" "  would backup: %s -> %s" "$target" "$backup"
    return 0
  fi

  mkdir -p "$(dirname "$backup")"
  mv "$target" "$backup"
  msg_line "  已备份：%s -> %s" "  backed up: %s -> %s" "$target" "$backup"
}

link_item() {
  local source="$1"
  local target_rel="$2"
  local target="${DOTFILES_HOME}/${target_rel}"

  if [ ! -e "$source" ]; then
    if is_en; then
      die "source does not exist: ${source}"
    else
      die "源路径不存在：${source}"
    fi
  fi

  if [ -L "$target" ]; then
    local current
    current="$(readlink "$target")"
    if [ "$current" = "$source" ]; then
      msg_line "  无需变更：%s" "  unchanged: %s" "$target_rel"
      return 0
    fi
    backup_existing_target "$target"
  elif [ -e "$target" ]; then
    backup_existing_target "$target"
  fi

  if [ "$DOTFILES_DRY_RUN" = "1" ]; then
    msg_line "  将创建链接：%s -> %s" "  would link: %s -> %s" "$target" "$source"
    return 0
  fi

  mkdir -p "$(dirname "$target")"
  ln -s "$source" "$target"
  msg_line "  已链接：%s" "  linked: %s" "$target_rel"
}

describe_link() {
  local source="$1"
  local target_rel="$2"
  local target="${DOTFILES_HOME}/${target_rel}"

  if [ -L "$target" ]; then
    local current
    current="$(readlink "$target")"
    if [ "$current" = "$source" ]; then
      msg_line "  - %s：已链接" "  - %s: already linked" "$target_rel"
    else
      msg_line "  - %s：替换现有符号链接，先备份" "  - %s: replace existing symlink, backup first" "$target_rel"
    fi
  elif [ -e "$target" ]; then
    msg_line "  - %s：备份现有路径，然后创建链接" "  - %s: backup existing path, then link" "$target_rel"
  else
    msg_line "  - %s：创建符号链接" "  - %s: create symlink" "$target_rel"
  fi
}

verify_link() {
  local source="$1"
  local target_rel="$2"
  local target="${DOTFILES_HOME}/${target_rel}"

  if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
    msg_line "  [成功] %s" "  [OK] %s" "$target_rel"
    return 0
  fi

  msg_line "  [失败] %s" "  [FAIL] %s" "$target_rel"
  return 1
}

run_module_phase() {
  local module="$1"
  local phase="$2"
  local script="${DOTFILES_ROOT}/modules/${module}/deploy.sh"

  if [ ! -x "$script" ]; then
    if is_en; then
      die "module script is missing or not executable: ${script}"
    else
      die "模块脚本不存在或不可执行：${script}"
    fi
  fi
  "$script" "$phase"
}
