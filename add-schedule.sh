#!/usr/bin/bash
echo=$(which echo)
pwd=$(which pwd)
test=$(which test)
sed=$(which sed)
tail=$(which tail)
readlink=$(which readlink)

current=$($pwd)
whoami=$(/usr/bin/whoami)
target=/etc/crontab

# User should be root
if [ $USER != "root" ]; then
  $echo "Should be run as root"
  exit 1;
fi

if $test ! -f "$1"; then
  $echo "Yaml file unexsist!"
  $echo "Usage: bash add-schedule.sh [yaml]"
  exit 1
fi

YAML_PATH=`$readlink -f $1`

ADDED_FLAG=`$tail $target | grep $1`

if [[ ! -z "${ADDED_FLAG}" ]]; then
  $echo "you have added $FLAG to /etc/crontab, replacing"
  $sed -i "/$1/d" $target
fi

$echo "* * * * * ${whoami} /usr/bin/bash ${current}/db-backup.sh -f $YAML_PATH" >> $target || exit 1

service cron reload

exit 0