#!/bin/bash
# crontab
# * * * * * /root/db_observer.sh > /root/db_observer.log 2> /root/db_observer.err

ACTIVE_DB_ZONE=$(curl "http://metadata.google.internal/computeMetadata/v1/project/attributes/ACTIVE_DB_ZONE" -H "Metadata-Flavor: Google")

date
SCRIPT_NAME=$(echo $0 | rev | cut -d/ -f1 | rev)
for pid in $(pidof -x ${SCRIPT_NAME}); do
    if [ $pid != $$ ]; then
        echo "[$(date)] : ${SCRIPT_NAME} : Process is already running with PID $pid"
        exit 1
    fi
done

echo "Active DB Zone is: ${ACTIVE_DB_ZONE}"
for TRIAL in {1..5}
do
    ./db_health_check.sh > /dev/null 2> /dev/null
    RET=$?
    if [ $RET -eq 0 ]; then
        echo "Database is healthy."
        exit 0
    fi
    echo "Attempt ${TRIAL}: DB health check fails."
    sleep 5
done

TARGET_ZONE=""
if [ "$ACTIVE_DB_ZONE" == "europe-west3-a" ]; then
    TARGET_ZONE=europe-west3-c
else
    TARGET_ZONE=europe-west3-a
fi

if [ ! -z "$TARGET_ZONE" ]
then
    echo "switching to target zone: ${TARGET_ZONE}..."
    gcloud compute project-info add-metadata --metadata=ACTIVE_DB_ZONE=${TARGET_ZONE}
    
    # Wait 5 minutes before next health check
    sleep 300
fi