#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${ROOT}/scripts/lib.sh"

usage() {
  if is_en; then
    cat <<'USAGE'
Usage:
  ./prepare.sh             Prepare zsh dependencies
  ./prepare.sh --en        Output English prompts and logs
  ./prepare.sh -h|--help   Show this help

This compatibility wrapper runs:
  ./modules/zsh/deploy.sh prepare

For the new one-step interactive deployment, use:
  ./install.sh
USAGE
  else
    cat <<'USAGE'
用法：
  ./prepare.sh             准备 zsh 依赖
  ./prepare.sh --en        使用英文提示和日志
  ./prepare.sh -h|--help   显示此帮助

这是兼容包装脚本，会执行：
  ./modules/zsh/deploy.sh prepare

新的单步交互式部署请使用：
  ./install.sh
USAGE
  fi
}

for arg in "$@"; do
  if [ "$arg" = "--en" ]; then
    DOTFILES_LANG="en"
    export DOTFILES_LANG
    break
  fi
done

while [ "$#" -gt 0 ]; do
  case "$1" in
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
        echo "ERROR: unknown argument: $1" >&2
      else
        echo "错误：未知参数：$1" >&2
      fi
      usage >&2
      exit 1
      ;;
  esac
  shift
done

msg_line "prepare.sh 保留为兼容包装脚本。" "prepare.sh is kept as a compatibility wrapper."
msg_line "新的单步交互式部署请使用 ./install.sh。" "Use ./install.sh for the new interactive one-step deployment."
echo ""

exec "${ROOT}/modules/zsh/deploy.sh" prepare
