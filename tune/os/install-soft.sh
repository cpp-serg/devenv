#!/bin/bash

MY_DIR=$(cd $(basedir $0); pwd)

sudo dnf install -y ripgrep fd-find
${MY_DIR}/install-tmux.sh

