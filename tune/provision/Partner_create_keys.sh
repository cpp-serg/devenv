#!/bin/bash
MY_DIR=$(cd $(dirname $0); pwd)
curl -X POST -H "Content-Type: application/json" http://127.0.0.1:8885/keys/create --data @${MY_DIR}/Partner_K4_211.json
curl -X POST -H "Content-Type: application/json" http://127.0.0.1:8885/keys/create --data @${MY_DIR}/Partner_OP_010.json
