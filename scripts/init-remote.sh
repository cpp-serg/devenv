#!/bin/bash

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <ip-address>"
    exit 1
fi

IP="$1"
HOST="root@${IP}"

ssh-copy-id "$HOST"
scp -r /opt/tools "$HOST":/opt/
scp ~/.ssh/id_rsa "$HOST":./.ssh
scp ~/.ssh/id_rsa.pub "$HOST":./.ssh
