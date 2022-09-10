#!/bin/bash

set -e
# set -x

SCRIPT_DIR="$(readlink -f $(dirname $0))"
SOURCE_DIR="${SCRIPT_DIR}/env"
TARGET_DIR="$(readlink -f ~)"

echo "Start deploy the dotfiles..."
echo ""

for file in $(ls -a "${SOURCE_DIR}" ); do
    if [ "${file}" == "." ] || [ "${file}" == ".." ]; then
        continue
    fi

    src="${SOURCE_DIR}/${file}"
    dst="${TARGET_DIR}/${file}"

    if [ -e ${dst} ]; then
        echo "[$(basename ${dst})] is already exist, skip!"
        sleep 0.2
        continue
    fi

    ln -s "${src}" "${dst}"
    echo "Link the $(basename ${file}) succeed!"
    sleep 0.2
done

echo ""
echo "Congratulation! Deploy all the dotfiles succeed!"
echo "Please restart the shell or execute \"source ~/.zshrc\""
echo ""

echo "Switching the default SHELL to zsh now."
echo "It may need you to input your passcode.(Enter to continue / Ctrl-C to cancel)"
read
chsh -s $(which zsh)

echo ""
echo "Done!"
