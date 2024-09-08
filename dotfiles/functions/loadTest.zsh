# Helper functions for load testing

####################################################################################################
# DUT functions
function ltAmfStats() {
    echo "AMF Stats"
    curl -m 1 -s 127.0.0.18:39091/metrics | grep -E "^(gnb|amf_session|ran_ue)"
}

function ltStatus() {
    ltAmfStats
    echo \nRoutes
    if (ip r | grep -E "172.2[45].*"); then
        return 0
    else
        echo "No 172.2{4,5} routes found"
        return 1
    fi
}

ALL_SERVICES=(pgw-cp.service pgw-up.service sgw-cp.service sgw-up.service gtp-broker.service 5g-broker.service amfd.service mmed.service 5g-broker.service)

function stopServices() {
    echo "Stopping services"
    systemctl stop ${ALL_SERVICES[@]}
}

function startServices() {
    echo "Starting services"
    systemctl start ${ALL_SERVICES[@]}
}

function servicesStatus() {
    echo "Services status"
    systemctl status ${ALL_SERVICES[@]} | rg --color=never "Active:" | rg --color=always ":.+\)"
}

function cleanLogs() {
    stopServices
    logNames=(5g-broker amfd ggsn  gtp-broker mmed)
    for logName in ${logNames[@]}; do
        echo "Cleaning $logName logs"
        /bin/rm /var/log/pente/$logName/*
    done
    startServices
}

####################################################################################################
# Client functions
function stopContainers {
    echo "Stopping docker processes"
    pids=($(docker ps -a -q))
    if [[ -z $pids ]]; then
        echo "No containers running"
    else
        docker rm -f $pids
        echo "Stopped ${#pids[@]} containers"
    fi
}

function loadStop() {
    echo "Stopping simulate_real_uesrs processes"
    pids=($(ps -ef | grep -i simulate_real_uesrs | grep -v grep | awk '{print $2}'))
    if [[ -z $pids ]]; then
        echo "No simulate_real_uesrs processes found"
    else
        kill -9 $pids && echo "Stopped $pids"
        echo "Stopped ${#pids[@]} processes"
    fi

    stopContainers
}

function loadStart() {
    count=$(ls *_run.sh | wc -l)
    echo "Starting load for $count scenarios"
    for c in $(seq 1 ${count}); do
        ./${c}_run.sh
        ./iperf_client_${c}.sh start
    done
    echo "Running $(docker ps -a -q | wc -l) containers"
}

####################################################################################################
# Server functions
function serverStart() {
    ~/iperf_server.sh start
}
function serverStop() {
    ~/iperf_server.sh stop
}
function serverRestart() {
    serverStop && serverStart
}
function serverStatus() {
    ~/iperf_server.sh status
}

