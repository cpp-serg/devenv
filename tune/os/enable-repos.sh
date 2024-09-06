#!/bin/bash

if (yum repolist all appstream | grep disabled >/dev/null) then
    echo "Enalbe repos"
    sudo dnf config-manager --enable "*"
    sudo dnf config-manager --disable "media*"
    sudo dnf install -y epel-release
else
    echo "Repos are enabled"
fi
