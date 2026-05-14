#!/usr/bin/env bash

set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOTFILES_HOME="${DOTFILES_HOME:-$HOME}"
DOTFILES_BACKUP_DIR="${DOTFILES_BACKUP_DIR:-${DOTFILES_HOME}/.dotfiles-backup/$(date +%Y%m%d%H%M%S)}"
DOTFILES_DRY_RUN="${DOTFILES_DRY_RUN:-0}"
DOTFILES_LANG="${DOTFILES_LANG:-zh}"
DOTFILES_FORCE_RELINK="${DOTFILES_FORCE_RELINK:-0}"

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
  local rel="${2:-${target#"$DOTFILES_HOME"/}}"
  local backup="${DOTFILES_BACKUP_DIR}/${rel}"

  if [ "$DOTFILES_DRY_RUN" = "1" ]; then
    msg_line "  将备份：%s -> %s" "  would backup: %s -> %s" "$target" "$backup"
    return 0
  fi

  mkdir -p "$(dirname "$backup")"
  mv "$target" "$backup"
  msg_line "  已备份：%s -> %s" "  backed up: %s -> %s" "$target" "$backup"
}

ensure_target_parent_dirs() {
  local target_rel="$1"
  local parent_rel="${target_rel%/*}"
  [ "$parent_rel" != "$target_rel" ] || return 0

  local part current_rel current_path
  local -a parts
  IFS='/' read -r -a parts <<< "$parent_rel"
  current_rel=""
  for part in "${parts[@]}"; do
    [ -n "$part" ] || continue
    if [ -n "$current_rel" ]; then
      current_rel="${current_rel}/${part}"
    else
      current_rel="$part"
    fi
    current_path="${DOTFILES_HOME}/${current_rel}"

    if [ -L "$current_path" ]; then
      backup_existing_target "$current_path" "$current_rel"
      [ "$DOTFILES_DRY_RUN" = "1" ] || mkdir -p "$current_path"
    elif [ -e "$current_path" ] && [ ! -d "$current_path" ]; then
      backup_existing_target "$current_path" "$current_rel"
      [ "$DOTFILES_DRY_RUN" = "1" ] || mkdir -p "$current_path"
    fi
  done
}

link_item() {
  local source="$1"
  local target_rel="$2"
  local target="${DOTFILES_HOME}/${target_rel}"
  link_item_at "$source" "$target_rel" "$target"
}

link_item_at() {
  local source="$1"
  local target_rel="$2"
  local target="$3"
  if [ ! -e "$source" ]; then
    if is_en; then
      die "source does not exist: ${source}"
    else
      die "源路径不存在：${source}"
    fi
  fi

  if [ "$target" = "${DOTFILES_HOME}/${target_rel}" ]; then
    ensure_target_parent_dirs "$target_rel"
  fi

  if [ -L "$target" ]; then
    local current
    current="$(readlink "$target")"
    if [ "$current" = "$source" ] && [ "$DOTFILES_FORCE_RELINK" != "1" ]; then
      msg_line "  无需变更：%s" "  unchanged: %s" "$target_rel"
      return 0
    fi
    backup_existing_target "$target" "$target_rel"
  elif [ -e "$target" ]; then
    backup_existing_target "$target" "$target_rel"
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
  describe_link_at "$source" "$target_rel" "$target"
}

describe_link_at() {
  local source="$1"
  local target_rel="$2"
  local target="$3"
  if [ -L "$target" ]; then
    local current
    current="$(readlink "$target")"
    if [ "$current" = "$source" ] && [ "$DOTFILES_FORCE_RELINK" != "1" ]; then
      msg_line "  - %s：已链接" "  - %s: already linked" "$target_rel"
    elif [ "$current" = "$source" ]; then
      msg_line "  - %s：强制重新链接，先备份现有链接" "  - %s: force relink, backup existing symlink first" "$target_rel"
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
  verify_link_at "$source" "$target_rel" "$target"
}

verify_link_at() {
  local source="$1"
  local target_rel="$2"
  local target="$3"
  if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
    msg_line "  [成功] %s" "  [OK] %s" "$target_rel"
    return 0
  fi

  msg_line "  [失败] %s" "  [FAIL] %s" "$target_rel"
  return 1
}

module_rel_path() {
  local path="$1"
  printf '%s\n' "${path#"$DOTFILES_ROOT"/}"
}

list_dir_names() {
  local dir="$1"
  [ -d "$dir" ] || return 0
  command ls -A "$dir" | sort
}

module_file_root_for() {
  local path="$1"
  local rel="$2"

  if [ ! -d "$path" ] || [ -L "$path" ]; then
    printf '%s\n' "$rel"
    return 0
  fi

  local entries=()
  local entry
  while IFS= read -r entry; do
    [ -n "$entry" ] && entries+=("$entry")
  done < <(list_dir_names "$path")

  if [ "${#entries[@]}" -eq 0 ]; then
    printf '%s\n' "$rel"
    return 0
  fi

  local dirs=()
  local has_file=0
  for entry in "${entries[@]}"; do
    if [ -d "${path}/${entry}" ] && [ ! -L "${path}/${entry}" ]; then
      dirs+=("$entry")
    else
      has_file=1
    fi
  done

  if [ "$has_file" -eq 1 ]; then
    printf '%s\n' "$rel"
  elif [ "${#dirs[@]}" -eq 1 ]; then
    module_file_root_for "${path}/${dirs[0]}" "${rel}/${dirs[0]}"
  else
    for entry in "${dirs[@]}"; do
      module_file_root_for "${path}/${entry}" "${rel}/${entry}"
    done
  fi
}

list_module_file_roots() {
  local module_dir="$1"
  local files_dir="${module_dir}/files"
  [ -d "$files_dir" ] || return 0

  local entry
  while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    module_file_root_for "${files_dir}/${entry}" "$entry"
  done < <(list_dir_names "$files_dir")
}

module_dep_manifest() {
  local module_dir="$1"
  local manifest="${module_dir}/dep/manifest.tsv"
  [ -f "$manifest" ] && printf '%s\n' "$manifest"
}

module_has_deps() {
  local module_dir="$1"
  local manifest
  manifest="$(module_dep_manifest "$module_dir" || true)"
  [ -n "$manifest" ]
}

gitmodule_url_for() {
  local rel="$1"
  git -C "$DOTFILES_ROOT" config -f "${DOTFILES_ROOT}/.gitmodules" --get "submodule.${rel}.url" 2>/dev/null || true
}

path_has_entries() {
  local path="$1"
  [ -d "$path" ] || return 1
  [ -n "$(command ls -A "$path" 2>/dev/null)" ]
}

update_one_module_dep() {
  local source="$1"
  local target="$2"
  local module_dir="$3"
  local source_path="${module_dir}/${source}"
  local source_rel url
  source_rel="$(module_rel_path "$source_path")"

  if git -C "$DOTFILES_ROOT" ls-files --stage -- "$source_rel" | grep -q '160000'; then
    if [ "$DOTFILES_DRY_RUN" = "1" ]; then
      msg_line "  将初始化 submodule：%s" "  would initialize submodule: %s" "$source_rel"
      return 0
    fi
    msg_line "  正在初始化 submodule：%s" "  initializing submodule: %s" "$source_rel"
    git -C "$DOTFILES_ROOT" submodule update --init --recursive -- "$source_rel"
    return 0
  fi

  if path_has_entries "$source_path"; then
    msg_line "  依赖已存在：%s" "  dependency already exists: %s" "$source_rel"
    return 0
  fi

  url="$(gitmodule_url_for "$source_rel")"
  if [ -z "$url" ]; then
    if is_en; then
      die "dependency is missing and no .gitmodules URL was found for ${source_rel}"
    else
      die "依赖缺失，且 .gitmodules 中未找到 URL：${source_rel}"
    fi
  fi

  if [ "$DOTFILES_DRY_RUN" = "1" ]; then
    msg_line "  将克隆依赖：%s -> %s" "  would clone dependency: %s -> %s" "$url" "$source_rel"
    return 0
  fi

  msg_line "  正在克隆依赖：%s" "  cloning dependency: %s" "$source_rel"
  mkdir -p "$(dirname "$source_path")"
  git clone --recursive "$url" "$source_path"
}

update_module_submodules() {
  local module_dir="$1"
  local manifest
  manifest="$(module_dep_manifest "$module_dir" || true)"
  [ -n "$manifest" ] || return 0

  msg_line "正在获取模块依赖..." "Fetching module dependencies..."
  local source target rest
  while IFS=$'\t' read -r source target rest || [ -n "$source" ]; do
    case "$source" in ''|\#*) continue ;; esac
    [ -n "${target:-}" ] || die "$(msg "dep manifest 缺少目标路径：%s" "dep manifest is missing target path: %s" "$manifest")"
    update_one_module_dep "$source" "$target" "$module_dir"
  done < "$manifest"
}

for_each_manifest_dep() {
  local module_dir="$1"
  local callback="$2"
  local manifest
  manifest="$(module_dep_manifest "$module_dir" || true)"
  [ -n "$manifest" ] || return 0

  local sources=()
  local targets=()
  local source target rest resolved_source resolved_target prefix suffix i
  while IFS=$'\t' read -r source target rest || [ -n "$source" ]; do
    case "$source" in ''|\#*) continue ;; esac
    [ -n "${target:-}" ] || die "$(msg "dep manifest 缺少目标路径：%s" "dep manifest is missing target path: %s" "$manifest")"

    resolved_source="${module_dir}/${source}"
    resolved_target="${DOTFILES_HOME}/${target}"
    for i in "${!targets[@]}"; do
      prefix="${targets[$i]}"
      case "$target" in
        "$prefix"/*)
          suffix="${target#"$prefix"/}"
          resolved_target="${sources[$i]}/${suffix}"
          ;;
      esac
    done

    "$callback" "$resolved_source" "$target" "$resolved_target"
    sources+=("$resolved_source")
    targets+=("$target")
  done < "$manifest"
}

describe_module_file() {
  describe_link_at "$1" "$2" "$3"
}

deploy_module_file() {
  link_item_at "$1" "$2" "$3"
}

verify_module_file() {
  verify_link_at "$1" "$2" "$3"
}

describe_dotfiles_module() {
  local module_dir="$1"
  local files_dir="${module_dir}/files"
  local rel
  while IFS= read -r rel; do
    describe_link "${files_dir}/${rel}" "$rel"
  done < <(list_module_file_roots "$module_dir")
  for_each_manifest_dep "$module_dir" describe_module_file
}

deploy_dotfiles_module() {
  local module_dir="$1"
  local files_dir="${module_dir}/files"
  local rel
  update_module_submodules "$module_dir"
  while IFS= read -r rel; do
    link_item "${files_dir}/${rel}" "$rel"
  done < <(list_module_file_roots "$module_dir")
  for_each_manifest_dep "$module_dir" deploy_module_file
}

verify_dotfiles_module() {
  local module_dir="$1"
  local files_dir="${module_dir}/files"
  local rel failed=0
  while IFS= read -r rel; do
    verify_link "${files_dir}/${rel}" "$rel" || failed=1
  done < <(list_module_file_roots "$module_dir")
  local manifest source target rest resolved_source resolved_target prefix suffix i
  local sources=()
  local targets=()
  manifest="$(module_dep_manifest "$module_dir" || true)"
  if [ -n "$manifest" ]; then
    while IFS=$'\t' read -r source target rest || [ -n "$source" ]; do
      case "$source" in ''|\#*) continue ;; esac
      [ -n "${target:-}" ] || die "$(msg "dep manifest 缺少目标路径：%s" "dep manifest is missing target path: %s" "$manifest")"
      resolved_source="${module_dir}/${source}"
      resolved_target="${DOTFILES_HOME}/${target}"
      for i in "${!targets[@]}"; do
        prefix="${targets[$i]}"
        case "$target" in
          "$prefix"/*)
            suffix="${target#"$prefix"/}"
            resolved_target="${sources[$i]}/${suffix}"
            ;;
        esac
      done
      verify_link_at "$resolved_source" "$target" "$resolved_target" || failed=1
      sources+=("$resolved_source")
      targets+=("$target")
    done < "$manifest"
  fi
  return "$failed"
}

run_module_phase() {
  local module="$1"
  local phase="$2"
  local module_dir="${DOTFILES_ROOT}/modules/${module}"

  if [ ! -d "$module_dir" ]; then
    if is_en; then
      die "module does not exist: ${module}"
    else
      die "模块不存在：${module}"
    fi
  fi

  case "$phase" in
    -h|--help|help)
      msg_line "用法：%s {describe|deploy|verify|help} [--en]" "Usage: %s {describe|deploy|verify|help} [--en]" "$module"
      ;;
    describe)
      describe_dotfiles_module "$module_dir"
      ;;
    deploy)
      deploy_dotfiles_module "$module_dir"
      ;;
    verify)
      verify_dotfiles_module "$module_dir"
      ;;
    *)
      if is_en; then die "usage: ${module} {describe|deploy|verify|help}"; else die "用法：${module} {describe|deploy|verify|help}"; fi
      ;;
  esac
}
