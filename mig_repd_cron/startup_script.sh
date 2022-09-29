#! /bin/bash

gsutil cp gs://ktchana-c4c-oracle-demo/monitor_active_db_zone.sh /root/
chmod u+x /root/monitor_active_db_zone.sh
crontab -l > /root/mycron
echo "* * * * * /root/monitor_active_db_zone.sh > /root/monitor_active_db_zone.log 2> /root/monitor_active_db_zone.err" >> /root/mycron
crontab /root/mycron
rm /root/mycron
