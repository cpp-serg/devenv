#!/bin/bash
USER_TO=${1:-root}
UNITS_ROOT=/usr/lib/systemd/system

#units=(5g-broker amfd mmed pgw-cp pgw-up sgw-cp sgw-up)
units=(pgw-cp pgw-up sgw-cp sgw-up)
echo "Changing user to ${USER_TO} in ${units[@]}"

for unit in "${units[@]}"
do
    fullUnitPath=$UNITS_ROOT/$unit.service
    cp $fullUnitPath $fullUnitPath.bak

    # change user and group to root with sed
    sed -iE "s/\(User\|Group\)=.*/\1=${USER_TO}/g" $fullUnitPath
    diff -u0 --color=always $fullUnitPath.bak $fullUnitPath
done

systemctl daemon-reload
systemctl stop ${units[@]}

chown -R ${USER_TO}:${USER_TO} /var/log/pente/ggsn

systemctl start ${units[@]}

