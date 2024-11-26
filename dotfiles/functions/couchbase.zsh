USER=Administrator
PASS=admin123

HOST=127.0.0.1
BUCKET=JPUHLR

typeset -A __cb_PGW_IDS # associative array logical name -> regex
__cb_PGW_IDS=(
    main      "[0-9]+::.*[.]json"
    prim      "jpu::Primary::[0-9]+"
    secondry  "jpu::Secondry::[0-9]+"
    usedbytes "jpu::[^:]+UsedBytes::[0-9]+"
    eu_ip     "jpu::tun[0-9]+::[0-9.]+"
    remote    "jpu::[0-9.]+:[0-9]+"
)

# name is key of __cb_PGW_IDS
function __cb_getRegex {
    name=$1
    echo "${__cb_PGW_IDS[$name]}"
}

function __cb_makeMatch {
    name=$1
    echo "regexp_matches(meta().id, '$(__cb_getRegex $name)')"
}

function __cb_makeAllPgwIdsMatch {
    matches=()
    for name in ${(k)__cb_PGW_IDS}; do
        matches+="$(__cb_makeMatch ${name})"
    done
    echo "${(j: or :)matches}" # join with ' or ' as a separator
}

__cb_PGW_ID_MATCH=$(__cb_makeAllPgwIdsMatch)

function cb-q
{
    if [[ "$SHOW_QUERY" == "1" ]]; then
        echo "$*;" | sed -E  -e "s/(where| or|COUNT|from)/\n  \1/g" >&2
        exit 0
    fi

    #Get first arg of exit with error
    cbq -q -u $USER -p $PASS -script "$*;" $HOST
}

function cb-all-keys
{
    cb-q "select raw meta().id from ${BUCKET}" \
    | jq -r ".results[]"
}

function cb-ls-keys {
    cb-q "select raw meta().id from JPUHLR where regexp_matches(meta().id, '$1')" \
    | jq -r ".results[]"
}

function cb-count-keys {
    cb-q "select raw count(meta().id) from JPUHLR where regexp_matches(meta().id, '$1')" \
    | jq -r ".results[]"
}

function cb-rm-keys {
    cb-q "delete from JPUHLR where regexp_matches(meta().id, '$1')" \
    | jq -r ".metrics.mutationCount"
}

function cb-pgw-main-keys {
    cb-ls-keys "$(__cb_getRegex main)"
}

function cb-pgw-prim-keys {
    cb-ls-keys "$(__cb_getRegex prim)"
}

function cb-pgw-sec-keys {
    cb-ls-keys "$(__cb_getRegex secondry)"
}

function cb-pgw-ub-keys {
    cb-ls-keys "$(__cb_getRegex usedbytes)"
}

function cb-pgw-eu_ip-keys {
    cb-ls-keys "$(__cb_getRegex eu_ip)"
}

function cb-pgw-remote-keys {
    cb-ls-keys "$(__cb_getRegex remote)"
}

function cb-show-session {
    imsi=$1
    cb-q "select * from JPUHLR where regexp_matches(meta().id, '${imsi}::.*.json')" \
    | jq -r --color-output ".results[].JPUHLR.pdp| del(.sessionQos,.nssai,.pcoNeg,.pcoReq, .secPdp[].qos, .userLocationInfo, .upLocation)"
}

function cb-pgw-counts {
    matches=()
    for name in ${(k)__cb_PGW_IDS}; do
        matches+="COUNT( case when $(__cb_makeMatch ${name}) THEN 1 END) as ${name}"
    done

    cb-q "select ${(j:, :)matches} from JPUHLR" \
    | jq -r -M '.results[] | to_entries | .[] | "\(.key) \(.value)"' \
    | column -t
}

function cb-pgw-keys {
    cb-q "select raw meta().id from JPUHLR where ${__cb_PGW_ID_MATCH}" \
    | jq -r '.results[]'
}

function cb-pgw-exps {
cb-q "select meta().id,  DATE_ADD_STR('1970-01-01T00:00:00Z', meta().expiration, 'second') AS exp_dt from JPUHLR where ${__cb_PGW_ID_MATCH}" \
    | jq -r -M '.results[] | "\(.exp_dt) \(.id)"' 
}


function cb-rm-pgw-keys {
    cb-q "delete from JPUHLR where ${__cb_PGW_ID_MATCH}" \
    | jq -r ".metrics.mutationCount"
}

