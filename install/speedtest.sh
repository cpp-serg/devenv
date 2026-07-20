#!/bin/bash

source "$(dirname "$0")/_install_preambule.sh"

curl -fsSL --retry 3 --retry-delay 2 https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.rpm.sh | ${SUDO} bash
${SUDO} dnf install -y speedtest

