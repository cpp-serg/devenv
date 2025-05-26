function pgwDeleteTopics() {
    pgw_id=$(pgwGetId)
    if [[ -z ${pgw_id} ]]; then
        echo "No PGW ID found"
        return
    fi

    /opt/kafka/bin/kafka-topics.sh --bootstrap-server 127.0.0.1:9092 --delete --topic ggsn_cp_${pgw_id}
    /opt/kafka/bin/kafka-topics.sh --bootstrap-server 127.0.0.1:9092 --delete --topic ggsn_up_${pgw_id}
}

