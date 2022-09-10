#!/bin/bash

set -e
# set -x

SCRIPT_DIR="$(readlink -f $(dirname $0))"
DEP_DIR="${SCRIPT_DIR}/dep"
ENV_DIR="${SCRIPT_DIR}/env"

OH_MY_ZSH_SRC="${DEP_DIR}/.oh-my-zsh"
OH_MY_ZSH_DST="${ENV_DIR}/.oh-my-zsh"

P10K_SRC="${DEP_DIR}/powerlevel10k"
P10K_DST="${ENV_DIR}/.oh-my-zsh/custom/themes/powerlevel10k"

ZSH_PLUGIN_AUTO_SUGGESTIONS_SRC="${DEP_DIR}/zsh-autosuggestions"
ZSH_PLUGIN_AUTO_SUGGESTIONS_DST="${ENV_DIR}/.oh-my-zsh/custom/plugin/zsh-autosuggestions"

ZSH_PLUGIN_COMPLETIONS_SRC="${DEP_DIR}/zsh-completions"
ZSH_PLUGIN_COMPLETIONS_DST="${ENV_DIR}/.oh-my-zsh/custom/plugin/zsh-completions"

ZSH_PLUGIN_SYNTAX_SRC="${DEP_DIR}/zsh-syntax-highlighting"
ZSH_PLUGIN_SYNTAX_DST="${ENV_DIR}/.oh-my-zsh/custom/plugin/zsh-syntax-highlighting"

# install required tools
sudo apt install -y zsh
sudo apt install -y vim curl git

# prepare for this repo
echo -n 'Fetch the dependencies...'
git submodule init
git submodule update
echo ' Done!'

# combine the dependencies
echo "put oh-my-zsh"
mkdir -p $(dirname ${OH_MY_ZSH_DST})
ln -s "${OH_MY_ZSH_SRC}" "${OH_MY_ZSH_DST}"

echo "put powerlevel10k"
mkdir -p $(dirname ${P10K_DST})
ln -s "${P10K_SRC}" "${P10K_DST}"

echo "put zsh plugins"
mkdir -p $(dirname ${ZSH_PLUGIN_AUTO_SUGGESTIONS_DST})
ln -s "${ZSH_PLUGIN_AUTO_SUGGESTIONS_SRC}" "${ZSH_PLUGIN_AUTO_SUGGESTIONS_DST}"
ln -s "${ZSH_PLUGIN_COMPLETIONS_SRC}" "${ZSH_PLUGIN_COMPLETIONS_DST}"
ln -s "${ZSH_PLUGIN_SYNTAX_SRC}" "${ZSH_PLUGIN_SYNTAX_DST}"

chsh -s $(which zsh)
