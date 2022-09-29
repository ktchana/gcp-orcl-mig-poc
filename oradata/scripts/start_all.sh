#!/bin/bash
export ORACLE_HOME=/mnt/oradata/orabase/dbhome
export PATH=$PATH:$ORACLE_HOME/bin
export ORACLE_SID=orcl19c

export ORAENV_ASK=NO
. oraenv
export ORAENV_ASK=YES

dbstart $ORACLE_HOME
