#!/bin/bash

# set ${SUDO} conditionally
SUDO=$([ $(id -u) -ne 0 ] && echo sudo)

curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.rpm.sh | ${SUDO} bash
${SUDO} dnf install -y speedtest

