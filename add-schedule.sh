#!/usr/bin/bash
echo=$(which echo)
bash=$(which bash)
pwd=$(which pwd)
test=$(which test)
sed=$(which sed)
tail=$(which tail)
readlink=$(which readlink)
grep=$(which grep)
dirname=$(which dirname)

base_dir=`$dirname $0`

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
  $echo "Usage: bash add-schedule.sh [yaml] [cron_set]"
  exit 1
fi

YAML_PATH=`$readlink -f $1`

FLAG=${YAML_PATH//\//\_}

ADDED_FLAG=`$tail $target | $grep $FLAG`

# run it at each hours, 00:05 01:05 ...
CRON_SET="5 * * * *"
# if you have determine at shell
if [[ ! -z "$2" ]]; then
  CRON_SET=$2
fi

if [[ ! -z "${ADDED_FLAG}" ]]; then
  $echo "you have added $YAML_PATH to /etc/crontab, replacing"
  $sed -i "/$FLAG/d" $target
fi

$echo "${CRON_SET} ${whoami} ${bash} ${base_dir}/db-backup.sh -f $YAML_PATH && $echo $FLAG" >> $target || exit 1

cat /etc/crontab

service cron reload

exit 0