USER=Administrator
PASS=admin123
HOST=127.0.0.1

function cb-q
{
    #Get first arg of exit with error
    cbq -q -u $USER -p $PASS -script "$*;" $HOST
}

function cb-all-keys
{
    BUCKET=${1:-JPUHLR}
    cb-q "select meta().id from ${BUCKET};" | jq -r ".results[].id"
}

function cb-ls-re-keys {
    cb-q "select meta().id            from JPUHLR where regexp_matches(meta().id, '$1')" | jq -r ".results[].id"
}

function cb-count-re-keys {
    cb-q "select raw count(meta().id) from JPUHLR where regexp_matches(meta().id, '$1')" | jq -r ".results[]"
}

function cb-rm-re-keys {
    cb-q "delete                      from JPUHLR where regexp_matches(meta().id, '$1')" | jq -r ".metrics.mutationCount"
}

function cb-ls-reneg-keys {
    cb-q "select meta().id            from JPUHLR where not regexp_matches(meta().id, '$1')" | jq -r ".results[].id"
}

function cb-count-reneg-keys {
    cb-q "select raw count(meta().id) from JPUHLR where not regexp_matches(meta().id, '$1')" | jq -r ".results[]"
}

function cb-rm-reneg-keys {
    cb-q "delete                      from JPUHLR where not regexp_matches(meta().id, '$1')" | jq -r ".metrics.mutationCount"
}

function cb-pgw-main-keys {
    cb-ls-re-keys "[0-9]+::.*[.]json"
}

function cb-pgw-prim-keys {
    cb-ls-re-keys "jpu::Primary::[0-9]+"
}

function cb-pgw-sec-keys {
    cb-ls-re-keys "jpu::Secondry::[0-9]+"
}

function cb-pgw-ub-keys {
    cb-ls-re-keys "jpu::[^:]+UsedBytes::[0-9]+"
}

function cb-pgw-tun-keys {
    cb-ls-re-keys "jpu::tun[0-9]+::[0-9.]+"
}

function cb-pgw-remote-keys {
    cb-ls-re-keys "jpu::[0-9.]+:[0-9]+"
}

function cb-show-dev
{
    imsi=$1
    cb-q "select * from JPUHLR where regexp_matches(meta().id, '${imsi}::.*.json')" \
    | jq -r --color-output ".results[].JPUHLR.pdp| del(.sessionQos,.nssai,.pcoNeg,.pcoReq, .secPdp[].qos, .userLocationInfo, .upLocation)"
}

function cb-show-pgw-counts
{
    imsi=$1
    cb-q "select COUNT(case when regexp_matches(meta().id, '[0-9]+::.*[.]json') THEN 1 END) as main,\
        COUNT(case when regexp_matches(meta().id, 'jpu::Primary::[0-9]+') THEN 1 END) as prim,\
        COUNT(case when regexp_matches(meta().id, 'jpu::Secondry::[0-9]+') THEN 1 END) as secondary,\
        COUNT(case when regexp_matches(meta().id, 'jpu::tun[0-9]+::[0-9.]+') THEN 1 END) as tunnel,\
        COUNT(case when regexp_matches(meta().id, 'jpu::[0-9.]+:[0-9]+') THEN 1 END) as remote,\
        COUNT(case when regexp_matches(meta().id, 'jpu::[^:]+UsedBytes::[0-9]+') THEN 1 END) as usedbytes from JPUHLR"\
    | jq -r -M '.results[] | to_entries | .[] | "\(.key) \(.value)"'\
    | column -t
}

function cb-pgw-keys
{
    cb-q "select meta().id from JPUHLR where \
        regexp_matches(meta().id, '[0-9]+::.*[.]json') \
        or regexp_matches(meta().id, 'jpu::Primary::[0-9]+') \
        or regexp_matches(meta().id, 'jpu::Secondry::[0-9]+') \
        or regexp_matches(meta().id, 'jpu::tun[0-9]+::[0-9.]+') \
        or regexp_matches(meta().id, 'jpu::[0-9.]+:[0-9]+') \
        or regexp_matches(meta().id, 'jpu::[^:]+UsedBytes::[0-9]+');" \
    | jq -r -M '.results[].id'
}

function cb-rm-pgw-keys
{
    cb-q "delete from JPUHLR where \
        regexp_matches(meta().id, '[0-9]+::.*[.]json') \
        or regexp_matches(meta().id, 'jpu::Primary::[0-9]+') \
        or regexp_matches(meta().id, 'jpu::Secondry::[0-9]+') \
        or regexp_matches(meta().id, 'jpu::tun[0-9]+::[0-9.]+') \
        or regexp_matches(meta().id, 'jpu::[0-9.]+:[0-9]+') \
        or regexp_matches(meta().id, 'jpu::[^:]+UsedBytes::[0-9]+');" \
        | jq -r ".metrics.mutationCount";

}

