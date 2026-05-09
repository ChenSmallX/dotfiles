#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${ROOT}/scripts/lib.sh"

MODULE_NAME=""
DRY_RUN=0

usage() {
  if is_en; then
    cat <<'USAGE'
Usage:
  ./add-module.sh                  Interactively add a dotfile module
  ./add-module.sh --module <name>  Use the specified module name
  ./add-module.sh --dry-run        Preview changes without writing files
  ./add-module.sh --en             Output English prompts and logs
  ./add-module.sh -h|--help        Show this help

Interactive selector:
  Up/Down or k/j      Move cursor
  Space               Select or unselect a file/directory
  Right or l          Enter directory
  Left or h           Go to parent directory
  Enter               Confirm selected paths

Selected local Git repositories are added as submodules under modules/<name>/dep/.
Other files and directories are copied into modules/<name>/files with their HOME-relative paths preserved.
USAGE
  else
    cat <<'USAGE'
用法：
  ./add-module.sh                  交互式添加 dotfile 模块
  ./add-module.sh --module <name>  使用指定模块名称
  ./add-module.sh --dry-run        仅预览变更，不写入文件
  ./add-module.sh --en             使用英文提示和日志
  ./add-module.sh -h|--help        显示此帮助

交互式选择器：
  上/下 或 k/j        移动光标
  空格                选择或取消选择文件/目录
  右 或 l             进入目录
  左 或 h             返回父目录
  回车                确认已选择路径

选中的本地 Git 仓库会作为 submodule 添加到 modules/<name>/dep/。
其他文件和目录会按 HOME 相对路径复制到 modules/<name>/files。
USAGE
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --module)
      [ "$#" -ge 2 ] || die "$(msg "缺少 --module 参数值" "missing --module value")"
      MODULE_NAME="$2"
      shift
      ;;
    --dry-run)
      DRY_RUN=1
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
      die "$(msg "未知参数：%s" "unknown argument: %s" "$1")"
      ;;
  esac
  shift
done

validate_module_name() {
  case "$1" in
    ""|.*|*/*|*\\*|*[^A-Za-z0-9._-]*)
      return 1
      ;;
  esac
  return 0
}

prompt_module_name() {
  while [ -z "$MODULE_NAME" ]; do
    msg "请输入模块名称（软件名）： " "Enter module name (software name): "
    read -r MODULE_NAME
  done
  validate_module_name "$MODULE_NAME" || die "$(msg "模块名称只能包含字母、数字、点、下划线和短横线，且不能以点开头：%s" "module name may only contain letters, numbers, dots, underscores, and dashes, and must not start with a dot: %s" "$MODULE_NAME")"
}

abs_path() {
  local path="$1"
  if [ -d "$path" ]; then
    (cd "$path" && pwd -P)
  else
    local dir base
    dir="$(dirname "$path")"
    base="$(basename "$path")"
    printf '%s/%s\n' "$(cd "$dir" && pwd -P)" "$base"
  fi
}

home_relative_path() {
  local path="$1"
  case "$path" in
    "$DOTFILES_HOME") printf '.\n' ;;
    "$DOTFILES_HOME"/*) printf '%s\n' "${path#"$DOTFILES_HOME"/}" ;;
    *) return 1 ;;
  esac
}

is_selected() {
  local path="$1"
  local item
  for item in "${SELECTED_PATHS[@]}"; do
    [ "$item" = "$path" ] && return 0
  done
  return 1
}

toggle_selected() {
  local path="$1"
  local next=()
  local item found=0
  for item in "${SELECTED_PATHS[@]}"; do
    if [ "$item" = "$path" ]; then
      found=1
    elif [ "$found" -eq 0 ]; then
      case "$path" in
        "$item"/*)
          return 0
          ;;
      esac
      case "$item" in
        "$path"/*)
          continue
          ;;
      esac
      next+=("$item")
    else
      next+=("$item")
    fi
  done
  if [ "$found" -eq 0 ]; then
    next+=("$path")
  fi
  SELECTED_PATHS=("${next[@]}")
}

load_entries() {
  local dir="$1"
  ENTRIES=("..")
  local item
  while IFS= read -r item; do
    ENTRIES+=("$item")
  done < <(command ls -A "$dir" | sort)
}

render_selector() {
  clear
  msg_line "选择要加入模块的配置文件或目录。空格选择，回车确认。" "Select config files or directories for the module. Space selects, Enter confirms."
  msg_line "当前目录：%s" "Current directory: %s" "$CURRENT_DIR"
  msg_line "已选择：%s" "Selected: %s" "${#SELECTED_PATHS[@]}"
  printf '\n'

  local i name path mark pointer suffix
  for i in "${!ENTRIES[@]}"; do
    name="${ENTRIES[$i]}"
    if [ "$name" = ".." ]; then
      path="$(dirname "$CURRENT_DIR")"
      suffix="/"
    else
      path="${CURRENT_DIR}/${name}"
      suffix=""
      [ -d "$path" ] && suffix="/"
    fi
    pointer=" "
    mark=" "
    [ "$i" -eq "$CURSOR" ] && pointer=">"
    [ "$name" != ".." ] && is_selected "$(abs_path "$path")" && mark="x"
    printf '%s [%s] %s%s\n' "$pointer" "$mark" "$name" "$suffix"
  done
}

select_paths() {
  CURRENT_DIR="$(abs_path "$DOTFILES_HOME")"
  SELECTED_PATHS=()
  CURSOR=0
  load_entries "$CURRENT_DIR"

  local key name target
  while true; do
    render_selector
    IFS= read -rsn1 key || true
    case "$key" in
      ''|$'\n'|$'\r')
        [ "${#SELECTED_PATHS[@]}" -gt 0 ] && break
        msg_line "请至少选择一个路径。" "Select at least one path."
        sleep 1
        ;;
      ' ')
        name="${ENTRIES[$CURSOR]}"
        if [ "$name" != ".." ]; then
          target="$(abs_path "${CURRENT_DIR}/${name}")"
          toggle_selected "$target"
        fi
        ;;
      l)
        name="${ENTRIES[$CURSOR]}"
        target="$([ "$name" = ".." ] && dirname "$CURRENT_DIR" || printf '%s/%s' "$CURRENT_DIR" "$name")"
        if [ -d "$target" ]; then
          CURRENT_DIR="$(abs_path "$target")"
          CURSOR=0
          load_entries "$CURRENT_DIR"
        fi
        ;;
      h)
        CURRENT_DIR="$(dirname "$CURRENT_DIR")"
        CURSOR=0
        load_entries "$CURRENT_DIR"
        ;;
      j) [ "$CURSOR" -lt $((${#ENTRIES[@]} - 1)) ] && CURSOR=$((CURSOR + 1)) ;;
      k) [ "$CURSOR" -gt 0 ] && CURSOR=$((CURSOR - 1)) ;;
      $'\033')
        IFS= read -rsn2 key || true
        case "$key" in
          '[A') [ "$CURSOR" -gt 0 ] && CURSOR=$((CURSOR - 1)) ;;
          '[B') [ "$CURSOR" -lt $((${#ENTRIES[@]} - 1)) ] && CURSOR=$((CURSOR + 1)) ;;
          '[C')
            name="${ENTRIES[$CURSOR]}"
            target="$([ "$name" = ".." ] && dirname "$CURRENT_DIR" || printf '%s/%s' "$CURRENT_DIR" "$name")"
            if [ -d "$target" ]; then
              CURRENT_DIR="$(abs_path "$target")"
              CURSOR=0
              load_entries "$CURRENT_DIR"
            fi
            ;;
          '[D')
            CURRENT_DIR="$(dirname "$CURRENT_DIR")"
            CURSOR=0
            load_entries "$CURRENT_DIR"
            ;;
        esac
        ;;
    esac
  done
}

is_git_repo_dir() {
  local path="$1"
  [ -d "$path" ] || return 1
  git -C "$path" rev-parse --show-toplevel >/dev/null 2>&1 || return 1
  [ "$(git -C "$path" rev-parse --show-toplevel)" = "$path" ]
}

git_remote_url() {
  local path="$1"
  git -C "$path" config --get remote.origin.url 2>/dev/null && return 0
  local remote
  remote="$(git -C "$path" remote 2>/dev/null | head -n 1)"
  [ -n "$remote" ] || return 1
  git -C "$path" config --get "remote.${remote}.url"
}

copy_config_item() {
  local source="$1"
  local rel="$2"
  local dest="${MODULE_DIR}/files/${rel}"
  if [ "$DRY_RUN" -eq 1 ]; then
    msg_line "  将复制：%s -> %s" "  would copy: %s -> %s" "$source" "$dest"
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  rm -rf "$dest"
  cp -a "$source" "$dest"
  msg_line "  已复制：%s -> %s" "  copied: %s -> %s" "$source" "$dest"
}

add_submodule_item() {
  local source="$1"
  local rel="$2"
  local name url dest
  name="$(basename "$source")"
  dest="dep/${name}"
  url="$(git_remote_url "$source")" || die "$(msg "Git 仓库没有可用 remote：%s" "Git repository has no usable remote: %s" "$source")"

  if [ -e "${MODULE_DIR}/${dest}" ]; then
    die "$(msg "submodule 目标路径已存在：%s" "submodule target already exists: %s" "$dest")"
  fi

  SUBMODULE_SOURCES+=("$dest")
  SUBMODULE_TARGETS+=("$rel")
  if [ "$DRY_RUN" -eq 1 ]; then
    msg_line "  将添加 submodule：%s -> modules/%s/%s" "  would add submodule: %s -> modules/%s/%s" "$url" "$MODULE_NAME" "$dest"
    return 0
  fi
  git -C "$ROOT" submodule add "$url" "modules/${MODULE_NAME}/${dest}"
  msg_line "  已添加 submodule：modules/%s/%s" "  added submodule: modules/%s/%s" "$MODULE_NAME" "$dest"
}

write_dep_manifest() {
  [ "${#SUBMODULE_SOURCES[@]}" -gt 0 ] || return 0
  local manifest="${MODULE_DIR}/dep/manifest.tsv"
  if [ "$DRY_RUN" -eq 1 ]; then
    return 0
  fi
  mkdir -p "$(dirname "$manifest")"
  printf '# source\ttarget\n' > "$manifest"
  local i
  for i in "${!SUBMODULE_SOURCES[@]}"; do
    printf '%s\t%s\n' "${SUBMODULE_SOURCES[$i]}" "${SUBMODULE_TARGETS[$i]}" >> "$manifest"
  done
}

prompt_module_name
MODULE_DIR="${ROOT}/modules/${MODULE_NAME}"
if [ -e "$MODULE_DIR" ]; then
  die "$(msg "模块已存在：%s" "module already exists: %s" "$MODULE_NAME")"
fi

select_paths

FILE_TARGETS=()
SUBMODULE_SOURCES=()
SUBMODULE_TARGETS=()

msg_line "将创建模块：%s" "Module to create: %s" "$MODULE_NAME"
for selected in "${SELECTED_PATHS[@]}"; do
  rel="$(home_relative_path "$selected")" || die "$(msg "所选路径必须位于 HOME 下：%s" "selected path must be under HOME: %s" "$selected")"
  if is_git_repo_dir "$selected"; then
    add_submodule_item "$selected" "$rel"
  else
    FILE_TARGETS+=("$rel")
    copy_config_item "$selected" "$rel"
  fi
done

if [ "$DRY_RUN" -eq 1 ]; then
  msg_line "预览完成，未写入任何文件。" "Dry-run completed. No files were written."
  exit 0
fi

mkdir -p "${MODULE_DIR}/files"
write_dep_manifest

msg_line "模块已创建：%s" "Module created: %s" "$MODULE_DIR"
msg_line "可以运行 ./install.sh --dry-run 预览部署影响。" "Run ./install.sh --dry-run to preview deployment impact."
