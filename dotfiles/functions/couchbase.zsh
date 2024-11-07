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


function cb-pgw-keys {
    cb-ls-reneg-keys "^(user::|auc::|IMSI_|sys_conf_|opname::|keys::|k4name::|AUC_JPU_KEYSET|iccid_imsi::|securedSuciKey::).*"
}


function cb-pgw-main-keys {
    # cb-ls-re-keys "[0-9]+::.*\.json"
    cb-ls-re-keys "[0-9]+::.*[.]json"
    # cb-ls-re-keys ".json"
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


function cb-count-pgw-keys {
    echo -n "Main: "
    cb-pgw-main-keys | wc -l
    echo -n "Primary: "
    cb-pgw-prim-keys | wc -l
    echo -n "Secondary: "
    cb-pgw-sec-keys | wc -l
    echo -n "Remote: "
    cb-pgw-remote-keys | wc -l
    echo -n "Tunnels: "
    cb-pgw-tun-keys | wc -l
    echo -n "Used Bytes: "
    cb-pgw-ub-keys | wc -l
}


# function cb-pgw-keys {
#     cb-all-keys | rg -v  "^(user::|auc::|IMSI_|sys_conf_|opname::|keys::|k4name::|AUC_JPU_KEYSET|iccid_imsi::)"
# }
