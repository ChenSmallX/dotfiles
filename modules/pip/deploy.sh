#!/usr/bin/env bash

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/scripts/lib.sh"
if parse_language_arg "${1:-}"; then shift; fi

MODULE_DIR="${DOTFILES_ROOT}/modules/pip"

case "${1:-}" in
  -h|--help|help)
    msg_line "用法：%s {describe|deploy|verify|help} [--en]" "Usage: %s {describe|deploy|verify|help} [--en]" "$0"
    ;;
  describe)
    describe_link "${MODULE_DIR}/files/.pip" ".pip"
    ;;
  deploy)
    link_item "${MODULE_DIR}/files/.pip" ".pip"
    ;;
  verify)
    verify_link "${MODULE_DIR}/files/.pip" ".pip"
    ;;
  *)
    if is_en; then die "usage: $0 {describe|deploy|verify|help}"; else die "用法：$0 {describe|deploy|verify|help}"; fi
    ;;
esac
