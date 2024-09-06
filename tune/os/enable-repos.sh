#!/bin/bash

if (yum repolist all appstream | grep disabled >/dev/null) then
    echo "Enalbe repos"
    dnf config-manager --enable "*"
    dnf config-manager --disable "media*"
else
    echo "Repos are enabled"
fi
