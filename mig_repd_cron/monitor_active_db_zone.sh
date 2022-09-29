#! /bin/bash
# crontab
# */2 * * * * /root/test.sh > /root/test.log 2> /root/test.err
REPD_NAME=pd-oradata

ACTIVE_DB_ZONE=$(curl "http://metadata.google.internal/computeMetadata/v1/project/attributes/ACTIVE_DB_ZONE" -H "Metadata-Flavor: Google")
INSTANCE_FQDN=$(curl http://metadata.google.internal/computeMetadata/v1/instance/hostname -H Metadata-Flavor:Google)
INSTANCE_NAME=$(echo $INSTANCE_FQDN | cut -d . -f1)
INSTANCE_ZONE=$(echo $INSTANCE_FQDN | cut -d . -f2)

SCRIPT_NAME=$(echo $0 | rev | cut -d/ -f1 | rev)
for pid in $(pidof -x ${SCRIPT_NAME}); do
    if [ $pid != $$ ]; then
        echo "[$(date)] : ${SCRIPT_NAME} : Process is already running with PID $pid"
        exit 1
    fi
done

if [ "$ACTIVE_DB_ZONE" == "$INSTANCE_ZONE" ]; then
    ORACLE_PROCESS_NAME="_pmon_"
    if pgrep "${ORACLE_PROCESS_NAME}" >/dev/null
    then
        echo "ORACLE is already running. Nothing to do."
        exit 0
    fi
else
    echo "ORACLE is running in another zone. Nothing to do."
    # kill any remaining listener to make sure that LB health check fails
    killall tnslsnr
    exit 0
fi

echo "ORACLE is not running. Starting instance..."

gcloud compute instances attach-disk ${INSTANCE_NAME}  \
    --disk ${REPD_NAME} --disk-scope regional \
    --zone ${INSTANCE_ZONE} \
    --force-attach

# add an entry in fstab for the regional pd (update it with the correct UUID) and mount it
#echo "UUID=d722aa9c-4757-49c2-a80f-0dd824fb0329 /mnt/oradata ext4 discard,defaults,nofail 0 2" >> /etc/fstab
mount -a

export ORACLE_HOME=/mnt/oradata/orabase/dbhome
export PATH=$PATH:$ORACLE_HOME/bin
export ORACLE_SID=orcl19c
export ORAENV_ASK=NO
. oraenv
export ORAENV_ASK=YES

### update tnsnames
echo "ORCL19C =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = ${INSTANCE_FQDN})(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = orcl19c)
    )
  )

LISTENER_ORCL19C =
  (ADDRESS = (PROTOCOL = TCP)(HOST = ${INSTANCE_FQDN})(PORT = 1521))" > $ORACLE_HOME/network/admin/tnsnames.ora


### update listener.ora
echo "LISTENER =
  (DESCRIPTION_LIST =
    (DESCRIPTION =
      (ADDRESS = (PROTOCOL = TCP)(HOST = ${INSTANCE_FQDN})(PORT = 1521))
      (ADDRESS = (PROTOCOL = IPC)(KEY = EXTPROC1521))
    )
  )" > $ORACLE_HOME/network/admin/listener.ora


### Stop any existing listener
killall tnslsnr

### startup listener and db
su -c 'lsnrctl start LISTENER' oracle
su -c 'sqlplus / as sysdba <<EOF
startup
EOF' oracle

# Sleep for a while to allow DB to stablise and before next monitoring take place
sleep 300
