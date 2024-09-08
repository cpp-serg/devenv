function ltAmfStats() {
    echo "AMF Stats"
    curl -m 1 -s 127.0.0.18:39091/metrics | grep -E "^(gnb|amf_session|ran_ue)"
}

function ltStatus() {
    ltAmfStats
    echo Routes
    if (ip r | grep -E "172.2[45].*"); then
        return 0
    else
        echo "No 172.2{4,5} routes found"
        return 1
    fi
}
