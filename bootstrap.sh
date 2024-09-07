#!/bin/bash
# sh -c "$(curl -fsSL https://raw.githubusercontent.com/cpp-serg/devenv/main/bootstrap.sh)"

TARGET_ROOT=~/devenv

# set ${SUDO} conditionally
SUDO=$([ $(id -u) -ne 0 ] && echo sudo)

git clone --recursive -j10 https://github.com/cpp-serg/devenv.git ${TARGET_ROOT}
cd ${TARGET_ROOT}
git remote set-url origin git@github.com:cpp-serg/devenv.git

${SUDO} ~/devenv/tune/os/enable-repos.sh
${SUDO} ~/devenv/tune/os/install-soft.sh

if ! type zsh >/dev/null 2>&1; then
    ${SUDO} dnf install -y zsh
    chsh -s /bin/zsh
fi

RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
mv ~/.zshrc ~/.zshrc.orig

${TARGET_ROOT}/dotfiles/set-links.sh

zsh

