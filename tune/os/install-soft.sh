#!/bin/bash

MY_DIR=$(cd $(dirname $0); pwd)

sudo dnf install -y ripgrep fd-find ninja-build
${MY_DIR}/install-tmux.sh
${MY_DIR}/install-cmake.sh

