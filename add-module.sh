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

Selected local Git repositories are added as submodules under dep/.
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

选中的本地 Git 仓库会作为 submodule 添加到 dep/。
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

quote_sh() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

quote_ps() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/''/g")"
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

  if [ -e "${ROOT}/${dest}" ]; then
    die "$(msg "submodule 目标路径已存在：%s" "submodule target already exists: %s" "$dest")"
  fi

  SUBMODULE_SOURCES+=("$dest")
  SUBMODULE_TARGETS+=("$rel")
  if [ "$DRY_RUN" -eq 1 ]; then
    msg_line "  将添加 submodule：%s -> %s" "  would add submodule: %s -> %s" "$url" "$dest"
    return 0
  fi
  git -C "$ROOT" submodule add "$url" "$dest"
  msg_line "  已添加 submodule：%s" "  added submodule: %s" "$dest"
}

generate_deploy_sh() {
  local script="${MODULE_DIR}/deploy.sh"
  {
    cat <<'EOF'
#!/usr/bin/env bash

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/scripts/lib.sh"
if parse_language_arg "${1:-}"; then shift; fi

MODULE_DIR="${DOTFILES_ROOT}/modules/__MODULE_NAME__"
FILES_SOURCES=(
EOF
    local item
    for item in "${FILE_TARGETS[@]}"; do
      printf '  "%s"\n' "\${MODULE_DIR}/files/${item}"
    done
    cat <<'EOF'
)
FILES_TARGETS=(
EOF
    for item in "${FILE_TARGETS[@]}"; do
      printf '  %s\n' "$(quote_sh "$item")"
    done
    cat <<'EOF'
)
SUBMODULE_SOURCES=(
EOF
    for item in "${SUBMODULE_SOURCES[@]}"; do
      printf '  "%s"\n' "\${DOTFILES_ROOT}/${item}"
    done
    cat <<'EOF'
)
SUBMODULE_TARGETS=(
EOF
    for item in "${SUBMODULE_TARGETS[@]}"; do
      printf '  %s\n' "$(quote_sh "$item")"
    done
    cat <<'EOF'
)

prepare_deps() {
  if [ "${#SUBMODULE_SOURCES[@]}" -gt 0 ]; then
    msg_line "正在获取 submodule 依赖..." "Fetching submodule dependencies..."
    git -C "$DOTFILES_ROOT" submodule update --init --recursive
  fi
}

describe_items() {
  local i
  for i in "${!FILES_SOURCES[@]}"; do
    describe_link "${FILES_SOURCES[$i]}" "${FILES_TARGETS[$i]}"
  done
  for i in "${!SUBMODULE_SOURCES[@]}"; do
    describe_link "${SUBMODULE_SOURCES[$i]}" "${SUBMODULE_TARGETS[$i]}"
  done
}

deploy_items() {
  local i
  prepare_deps
  for i in "${!FILES_SOURCES[@]}"; do
    link_item "${FILES_SOURCES[$i]}" "${FILES_TARGETS[$i]}"
  done
  for i in "${!SUBMODULE_SOURCES[@]}"; do
    link_item "${SUBMODULE_SOURCES[$i]}" "${SUBMODULE_TARGETS[$i]}"
  done
}

verify_items() {
  local i failed=0
  for i in "${!FILES_SOURCES[@]}"; do
    verify_link "${FILES_SOURCES[$i]}" "${FILES_TARGETS[$i]}" || failed=1
  done
  for i in "${!SUBMODULE_SOURCES[@]}"; do
    verify_link "${SUBMODULE_SOURCES[$i]}" "${SUBMODULE_TARGETS[$i]}" || failed=1
  done
  return "$failed"
}

case "${1:-}" in
  -h|--help|help)
    msg_line "用法：%s {describe|deploy|verify|help} [--en]" "Usage: %s {describe|deploy|verify|help} [--en]" "$0"
    ;;
  describe) describe_items ;;
  deploy) deploy_items ;;
  verify) verify_items ;;
  *)
    if is_en; then die "usage: $0 {describe|deploy|verify|help}"; else die "用法：$0 {describe|deploy|verify|help}"; fi
    ;;
esac
EOF
  } | sed "s/__MODULE_NAME__/${MODULE_NAME}/g" > "$script"
  chmod +x "$script"
}

generate_deploy_ps1() {
  local script="${MODULE_DIR}/deploy.ps1"
  {
    cat <<'EOF'
$ErrorActionPreference = "Stop"
Import-Module (Join-Path $PSScriptRoot "..\..\scripts\Dotfiles.psm1") -Force
$ModuleDir = $PSScriptRoot
$ScriptArgs = @($args)
if ($ScriptArgs.Count -gt 0 -and $ScriptArgs[0] -eq "--en") {
    Set-DotfilesEnglish
    $ScriptArgs = @($ScriptArgs | Select-Object -Skip 1)
}

$FileItems = @(
EOF
    local item first=1
    for item in "${FILE_TARGETS[@]}"; do
      [ "$first" -eq 0 ] && printf ',\n'
      printf '    @{ Source = (Join-Path $ModuleDir %s); Target = %s }' "$(quote_ps "files\\${item//\//\\}")" "$(quote_ps "$item")"
      first=0
    done
    printf '\n'
    cat <<'EOF'
)
$SubmoduleItems = @(
EOF
    first=1
    local idx
    for idx in "${!SUBMODULE_SOURCES[@]}"; do
      [ "$first" -eq 0 ] && printf ',\n'
      printf '    @{ Source = (Join-Path (Get-DotfilesRoot) %s); Target = %s }' "$(quote_ps "${SUBMODULE_SOURCES[$idx]//\//\\}")" "$(quote_ps "${SUBMODULE_TARGETS[$idx]}")"
      first=0
    done
    printf '\n'
    cat <<'EOF'
)

function Show-Usage {
    Write-DotfilesMessage "用法：deploy.ps1 {describe|deploy|verify|help} [--en]" "Usage: deploy.ps1 {describe|deploy|verify|help} [--en]"
}

function Initialize-Submodules {
    if ($SubmoduleItems.Count -gt 0) {
        Write-DotfilesMessage "正在获取 submodule 依赖..." "Fetching submodule dependencies..."
        git -C (Get-DotfilesRoot) submodule update --init --recursive
    }
}

switch ($ScriptArgs[0]) {
    "-h" { Show-Usage }
    "--help" { Show-Usage }
    "help" { Show-Usage }
    "describe" {
        foreach ($item in $FileItems) { Show-DotfileImpact $item.Source $item.Target }
        foreach ($item in $SubmoduleItems) { Show-DotfileImpact $item.Source $item.Target }
    }
    "deploy" {
        Initialize-Submodules
        foreach ($item in $FileItems) { Install-DotfileItem $item.Source $item.Target }
        foreach ($item in $SubmoduleItems) { Install-DotfileItem $item.Source $item.Target }
    }
    "verify" {
        $failed = $false
        foreach ($item in $FileItems) { if (-not (Test-DotfileItem $item.Source $item.Target)) { $failed = $true } }
        foreach ($item in $SubmoduleItems) { if (-not (Test-DotfileItem $item.Source $item.Target)) { $failed = $true } }
        if ($failed) { throw (Get-DotfilesMessage "验证失败" "verification failed") }
    }
    default {
        Show-Usage
        throw (Get-DotfilesMessage "未知阶段：$($ScriptArgs[0])" "unknown phase: $($ScriptArgs[0])")
    }
}
EOF
  } > "$script"
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
generate_deploy_sh
generate_deploy_ps1

msg_line "模块已创建：%s" "Module created: %s" "$MODULE_DIR"
msg_line "可以运行 ./install.sh --dry-run 预览部署影响。" "Run ./install.sh --dry-run to preview deployment impact."
