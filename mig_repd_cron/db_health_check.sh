#!/bin/bash

timeout 5 sqlplus system/oracle1@10.156.0.12:1521/orcl19c <<EOF
WHENEVER OSERROR EXIT 101
WHENEVER SQLERROR EXIT 102
select to_char(sysdate, 'yyyy-mm-dd hh24:mi:ss') CUR_DATE from dual;
exit 99
EOF

RET=$?
if [ $RET -ne 99 ]; then
    echo "DB Failed. Return code: ${RET}"
    exit 1
fi
