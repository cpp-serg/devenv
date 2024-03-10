#!/bin/bash
# sh -c "$(curl -fsSL https://raw.githubusercontent.com/cpp-serg/devenv/bootstrap.sh)"

TARGET_ROOT=~/devenv

git clone --recursive https://github.com/cpp-serg/devenv.git ${TARGET_ROOT}

${TARGET_ROOT}/dotfiles/set-links.sh

