#!/bin/bash
# sh -c "$(curl -fsSL https://raw.githubusercontent.com/cpp-serg/devenv/main/bootstrap.sh)"

TARGET_ROOT=~/devenv

git clone --recursive -j10 https://github.com/cpp-serg/devenv.git ${TARGET_ROOT}

sudo ~/devenv/tune/os/enable-repos.sh

if ! type zsh >/dev/null 2>&1; then
    sudo dnf install -y zsh
fi

sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
mv ~/.zshrc ~/.zshrc.orig

${TARGET_ROOT}/dotfiles/set-links.sh

