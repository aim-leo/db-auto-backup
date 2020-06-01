#!/usr/bin/bash
PWD=/usr/bin/pwd
ECHO=/usr/bin/echo

CURRENT=$($PWD)
WHOAMI=$(/usr/bin/whoami)

FLAG="added-db-backup-schedule"

echo $FLAG

ADDED_FLAG=$(tail /etc/crontab | grep $FLAG)

if [[ ! -z "${ADDED_FLAG}" ]]; then
  $ECHO "you have added $FLAG to /etc/crontab, skipping"
  exit 0
fi

$ECHO "* * * * * ${WHOAMI} /usr/bin/bash ${CURRENT}/backup-qt.sh && $ECHO $FLAG" >> /etc/crontab || exit 1

service cron reload

exit 0