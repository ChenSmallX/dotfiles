#!/bin/bash

set -e
# set -x

SCRIPT_DIR="$(readlink -f $(dirname $0))"
SOURCE_DIR="${SCRIPT_DIR}/env"
TARGET_DIR="$(readlink -f ~)"

echo "Start deploy the dotfiles..."

for file in $(ls -a "${SOURCE_DIR}" ); do
    if [ "${file}" == "." ] || [ "${file}" == ".." ]; then
        continue
    fi

    src="${SOURCE_DIR}/${file}"
    dst="${TARGET_DIR}/${file}"

    if [ -e ${dst} ]; then
        echo "${dst} is already exist, skip!"
        continue
    fi

    ln -s "${src}" "${dst}"
    echo "Link the ${file} succeed!"
done

echo "Congratulation! Deploy all the dotfiles succeed!"
echo "Please restart the shell or execute \"source ~/.zshrc\""

echo "Switching shell to zsh... It need you input your passcode maybe."
chsh -s $(which zsh)

echo ""
echo "Done!"
