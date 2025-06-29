
function pgwGetId() {
    grep -v "#" /home/pente/ggsn/bin/pgw.uuid 2>/dev/null
}

# change user in pente units for PGW/SGW.
# Also change log directory
# Usage: changeGwUser [user_to=root]
function changeGwUser {
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
}


function linkCustomBins {
    buildRoot=${1:-/root/ggsn}
    echo "Using custom binaries from ${buildRoot}"
    for binary in GGSN/ggsn SGW/cp/sgw_cp SGW/up/sgw_up
    do
        bin=$(basename $binary)
        ln -sf ${buildRoot}/build/current/${binary} /home/pente/ggsn/bin/${bin}-custom
    done
}


function moveOriginalBins {
    for binary in ggsn sgw_cp sgw_up
    do
        binPath=/home/pente/ggsn/bin/${binary}
        if [[ ! -L ${binPath} && ! -f ${binPath}-orig ]]; then
            mv ${binPath} ${binPath}-orig
        fi
    done
}


function restoreOriginalBins {
    for binary in ggsn sgw_cp sgw_up
    do
        binPath=/home/pente/ggsn/bin/${binary}
        if [[ -f ${binPath}-orig ]]; then
            if [[ -e ${binPath} ]]; then
                if [[ -L ${binPath} ]]; then
                    rm ${binPath}
                else
                    echo "WARNING: ${binPath} is not a symlink, was not restored"
                    continue
                fi
            fi
            mv ${binPath}-orig ${binPath}
        fi
    done

    for binary in ggsn sgw_cp sgw_up
    do
        chown pente:pente /home/pente/ggsn/bin/${binary}
        setcap cap_net_admin=+ep /home/pente/ggsn/bin/${binary}
    done
    changeGwUser pente
}

function gwstart() {
    systemctl start {p,s}gw-{c,u}p
}

function gwstop() {
    systemctl stop {p,s}gw-{c,u}p
}

function gwrestart {
    systemctl restart {p,s}gw-{c,u}p
}

function gwstatus() {
    systemctl status {p,s}gw-{c,u}p amfd | rg --color=never "Active:" | rg --color=always ":.+\)"
    ps -elf | rg "ggsn|amfd" | rg -v "(bash|rg)" | cut -c-${COLUMNS}
}

function useCustomBins {
    buildRoot=${1:-/root/ggsn}
    for binary in ggsn sgw_cp sgw_up
    do
        if [[ ! -L /home/pente/ggsn/bin/${binary} ]]; then
            moveOriginalBins
            break
        fi
    done

    for binary in ggsn sgw_cp sgw_up
    do
        if [[ ! -L /home/pente/ggsn/bin/${binary}-custom ]]; then
            linkCustomBins ${buildRoot}
            break
        fi
    done

    for binary in ggsn sgw_cp sgw_up
    do
        ln -sf /home/pente/ggsn/bin/${binary}-custom /home/pente/ggsn/bin/${binary}
    done
    changeGwUser root
}


function useOriginalBins {
    for binary in ggsn sgw_cp sgw_up
    do
        ln -sf /home/pente/ggsn/bin/${binary}-orig /home/pente/ggsn/bin/${binary}
    done
}

