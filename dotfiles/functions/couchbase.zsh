USER=Administrator
PASS=admin123
HOST=127.0.0.1

function cb-all-keys
{
    BUCKET=${1:-JPUHLR}
    # cbq -q -u $USER -p $PASS -script "select RAW meta().id from ${BUCKET};" $HOST | jq -r ".results"
    # same but just values, no []
    cbq -q -u $USER -p $PASS -script "select meta().id from ${BUCKET};" $HOST | jq -r ".results[].id"
}

function cb-pgw-keys {
    cb-all-keys | rg -v  "^(user::|auc::|IMSI_|sys_conf_|opname::|keys::|k4name::|AUC_JPU_KEYSET)"
}
