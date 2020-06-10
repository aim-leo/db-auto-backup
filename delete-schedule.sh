#!/usr/bin/bash
echo=$(which echo)
test=$(which test)
sed=$(which sed)
tail=$(which tail)
readlink=$(which readlink)

target=/etc/crontab

# User should be root
if [ $USER != "root" ]; then
  $echo "Should be run as root"
  exit 1;
fi

if $test ! -f "$1"; then
  $echo "Yaml file unexsist!"
  $echo "Usage: bash delete-schedule.sh [yaml]"
  exit 1
fi

YAML_PATH=`$readlink -f $1`

ADDED_FLAG=`$tail $target | grep $1`

if [[ ! -z "${ADDED_FLAG}" ]]; then
  $echo "Deleting schedule at $1"
  $sed -i "/$1/d" $target
  if [ $? -ne 0 ]; then
    $echo "Deleting schedule $1 fail!"
    exit 1
  fi
else
  $echo "Deleting schedule $1 fail! this schedule is unregister!"
  exit 1
fi

cat /etc/crontab

service cron reload

$echo "Deleting schedule $1 success!"

exit 0