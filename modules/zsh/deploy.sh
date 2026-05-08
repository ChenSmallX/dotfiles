#!/usr/bin/env bash

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/scripts/lib.sh"
if parse_language_arg "${1:-}"; then shift; fi

MODULE_DIR="${DOTFILES_ROOT}/modules/zsh"
DEP_DIR="${DOTFILES_ROOT}/dep"
OMZ_DIR="${DEP_DIR}/.oh-my-zsh"

prepare_zsh() {
  if is_windows_like; then
    msg_line "在类 Windows shell 中跳过 zsh 准备。" "zsh prepare is skipped on Windows-like shells."
    return 0
  fi

  ensure_tools zsh vim curl wget git

  msg_line "正在获取 submodule 依赖..." "Fetching submodule dependencies..."
  git -C "$DOTFILES_ROOT" submodule update --init --recursive

  msg_line "正在准备 oh-my-zsh 依赖..." "Preparing oh-my-zsh dependencies..."
  link_item "${OMZ_DIR}" ".oh-my-zsh"
  link_item "${DEP_DIR}/powerlevel10k" ".oh-my-zsh/custom/themes/powerlevel10k"
  link_item "${DEP_DIR}/zsh-autosuggestions" ".oh-my-zsh/custom/plugins/zsh-autosuggestions"
  link_item "${DEP_DIR}/zsh-completions" ".oh-my-zsh/custom/plugins/zsh-completions"
  link_item "${DEP_DIR}/zsh-syntax-highlighting" ".oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
}

case "${1:-}" in
  -h|--help|help)
    if is_en; then
      cat <<'USAGE'
Usage:
  modules/zsh/deploy.sh prepare   Prepare zsh dependencies
  modules/zsh/deploy.sh describe  Show deployment impact
  modules/zsh/deploy.sh deploy    Deploy zsh files and dependencies
  modules/zsh/deploy.sh verify    Verify deployed links
  modules/zsh/deploy.sh --en      Output English prompts and logs
  modules/zsh/deploy.sh --help    Show this help
USAGE
    else
      cat <<'USAGE'
用法：
  modules/zsh/deploy.sh prepare   准备 zsh 依赖
  modules/zsh/deploy.sh describe  显示部署影响
  modules/zsh/deploy.sh deploy    部署 zsh 文件和依赖
  modules/zsh/deploy.sh verify    验证部署链接
  modules/zsh/deploy.sh --en      使用英文提示和日志
  modules/zsh/deploy.sh --help    显示此帮助
USAGE
    fi
    ;;
  prepare)
    prepare_zsh
    ;;
  describe)
    if is_windows_like; then
      msg_line "  - zsh：在类 Windows shell 中跳过" "  - zsh: skipped on Windows-like shells"
    else
      describe_link "${MODULE_DIR}/files/.zshrc" ".zshrc"
      describe_link "${MODULE_DIR}/files/.p10k.zsh" ".p10k.zsh"
      describe_link "${MODULE_DIR}/files/.zshrc.pre-oh-my-zsh" ".zshrc.pre-oh-my-zsh"
      describe_link "${OMZ_DIR}" ".oh-my-zsh"
      describe_link "${DEP_DIR}/powerlevel10k" ".oh-my-zsh/custom/themes/powerlevel10k"
      describe_link "${DEP_DIR}/zsh-autosuggestions" ".oh-my-zsh/custom/plugins/zsh-autosuggestions"
      describe_link "${DEP_DIR}/zsh-completions" ".oh-my-zsh/custom/plugins/zsh-completions"
      describe_link "${DEP_DIR}/zsh-syntax-highlighting" ".oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
      msg_line "  - 默认 shell：部署后询问是否切换到 zsh" "  - default shell: offer to switch to zsh after deployment"
    fi
    ;;
  deploy)
    prepare_zsh
    link_item "${MODULE_DIR}/files/.zshrc" ".zshrc"
    link_item "${MODULE_DIR}/files/.p10k.zsh" ".p10k.zsh"
    link_item "${MODULE_DIR}/files/.zshrc.pre-oh-my-zsh" ".zshrc.pre-oh-my-zsh"
    if command_exists chsh && command_exists zsh && [ "${DOTFILES_DRY_RUN}" != "1" ]; then
      msg_line "是否将默认 shell 切换到 zsh？按回车继续，或按 Ctrl-C 跳过。" "Switch default shell to zsh? Press Enter to continue, or Ctrl-C to skip."
      read -r _
      chsh -s "$(command -v zsh)"
    fi
    ;;
  verify)
    if is_windows_like; then
      msg_line "  [OK] zsh 已在类 Windows shell 中跳过" "  [OK] zsh skipped on Windows-like shells"
    else
      verify_link "${MODULE_DIR}/files/.zshrc" ".zshrc"
      verify_link "${MODULE_DIR}/files/.p10k.zsh" ".p10k.zsh"
      verify_link "${MODULE_DIR}/files/.zshrc.pre-oh-my-zsh" ".zshrc.pre-oh-my-zsh"
      verify_link "${OMZ_DIR}" ".oh-my-zsh"
      verify_link "${DEP_DIR}/powerlevel10k" ".oh-my-zsh/custom/themes/powerlevel10k"
      verify_link "${DEP_DIR}/zsh-autosuggestions" ".oh-my-zsh/custom/plugins/zsh-autosuggestions"
      verify_link "${DEP_DIR}/zsh-completions" ".oh-my-zsh/custom/plugins/zsh-completions"
      verify_link "${DEP_DIR}/zsh-syntax-highlighting" ".oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
    fi
    ;;
  *)
    if is_en; then die "usage: $0 {prepare|describe|deploy|verify|help}"; else die "用法：$0 {prepare|describe|deploy|verify|help}"; fi
    ;;
esac
