#!/usr/bin/env bash

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/scripts/lib.sh"
if parse_language_arg "${1:-}"; then shift; fi

MODULE_DIR="${DOTFILES_ROOT}/modules/tmux"

case "${1:-}" in
  -h|--help|help)
    msg_line "用法：%s {describe|deploy|verify|help} [--en]" "Usage: %s {describe|deploy|verify|help} [--en]" "$0"
    ;;
  describe)
    describe_link "${MODULE_DIR}/files/.tmux.conf" ".tmux.conf"
    describe_link "${MODULE_DIR}/files/.tmux" ".tmux"
    ;;
  deploy)
    ensure_tools tmux
    link_item "${MODULE_DIR}/files/.tmux.conf" ".tmux.conf"
    link_item "${MODULE_DIR}/files/.tmux" ".tmux"
    ;;
  verify)
    verify_link "${MODULE_DIR}/files/.tmux.conf" ".tmux.conf"
    verify_link "${MODULE_DIR}/files/.tmux" ".tmux"
    ;;
  *)
    if is_en; then die "usage: $0 {describe|deploy|verify|help}"; else die "用法：$0 {describe|deploy|verify|help}"; fi
    ;;
esac
