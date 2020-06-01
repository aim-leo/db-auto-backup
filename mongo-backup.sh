#!/usr/bin/bash

ECHO=/usr/bin/echo
PWD=/usr/bin/pwd
MKDIR=/usr/bin/mkdir
TEST=/usr/bin/test
GIT=/usr/bin/git
TAR=/usr/bin/tar
MV=/usr/bin/mv
RM=/usr/bin/rm


TIME=$(date "+%Y-%m-%d_%H-%M-%S")
CURRENT=$($PWD)
PARENT_DIR="cd $CURRENT/.. && $PWD"
VERSION="1.0.1"

function usage
{
  $ECHO "Usage:"
  $ECHO "  -d | --database [database]            Input the database you want to dump"
  $ECHO "  -o | --output_dir [output_dir]        Input the dir you want to output the file, defalut current path"
  $ECHO "  -f | --filename [filename]            Input the filename, default DATABASE_db_TIME"
  $ECHO "  -l | --log_dir [log_dir]              Input the dir you want to output the log, defalut output_dir"
  $ECHO "  -c | --docker_container [container]   If your mongo is runing at docker, Input the container ID or name here"
  $ECHO "  -u | --docker_uri [uri]               Input the mongo uri, default is localhost:27017"
  $ECHO "  -p | --push2git                       Whether to auto add && commit && push to $GIT, default false"
  $ECHO "  -g | --gzip                           Whether to gzip the dir, default false"
  $ECHO "  -h | --help                           Get help"
  $ECHO "  -v | --version                        Get current version"
}

function version
{
  $ECHO $VERSION
}

function log
{
  FORMAT_TIME=$(date "+%Y-%m-%d %H:%M:%S")
  $ECHO "[$FORMAT_TIME] [MONGO BACKUP] $1"
  $ECHO "[$FORMAT_TIME] [MONGO BACKUP] $1" >> ${LOG_DIR}/backup.log
}

function ensure_dir
{
  if ! $TEST -d "$1"; then
    log "ensure_dir: $1 unexist, try to create it"
    $MKDIR $1 || exit 1
  fi
}

function check_cmd
{
  if ! command -v $1 > /dev/null 2>&1;then
    log "check_cmd: $1 is required, please install it"
    exit 1
  fi
}

function check_git_dir
{
  if ! $TEST -d "$1"; then
    log "check_git_dir: $1 unexist"
  fi

  cd $1
  $GIT status || exit 1
}


function parse_args
{
  args=()
  
  OUTPUT_DIR=$CURRENT
  GZIP=false
  PUSH_TO_GIT=false
  DOCKER_URI="localhost:27017"

  # named args
  while [ "$1" != "" ]; do
    case "$1" in
      -d | --database )                 DATABASE="$2";                  shift;;
      -o | --output_dir )               OUTPUT_DIR="$2";                shift;;
      -f | --filename )       		      FILE_NAME="$2";                 shift;;
      -l | --log_dir )                  LOG_DIR="$2";                   shift;;
      -c | --docker_container )         DOCKER_CONATINER="$2";          shift;;
      -u | --docker_uri )               DOCKER_URI="$2";                shift;;
      -p | --push2git )                 PUSH_TO_GIT=true;               ;;
      -g | --gzip )                     GZIP=true;                      ;;
      -h | --help )                     usage;                          exit;;
      -v | --version )                  version;                        exit;;
      * )                               args+=("$1")
    esac
    shift # move to next kv pair
  done

  FILE_NAME=$DATABASE"_db_"$TIME
  FILE_PATH=$OUTPUT_DIR/$FILE_NAME

  # check database
  if [[ -z "${LOG_DIR}" ]]; then
    LOG_DIR=$OUTPUT_DIR
  fi

  # check database
  if [[ -z "${DATABASE}" ]]; then
    log "Required database name, please input -d [database] or --database [database]"
    usage
    exit 1;
  fi


  # restore positional args
  set -- "${args[@]}"

  # make sure out dir exsit
  ensure_dir $OUTPUT_DIR

  # make sure log dir exsit
  ensure_dir $LOG_DIR
}

function dump
{
  if [[ -z "${DOCKER_CONATINER}" ]]; then
    check_cmd /usr/bin/mongodump

    /usr/bin/mongodump -h $DOCKER_URI -d $DATABASE -o $FILE_PATH || exit 1
  else
    DOCKER=/usr/bin/docker
    check_cmd $DOCKER

    $DOCKER exec $DOCKER_CONATINER /bin/bash -c "/usr/bin/mongodump -h $DOCKER_URI -d $DATABASE -o /tmp/$FILE_NAME" || exit 1
    $DOCKER cp $DOCKER_CONATINER:/tmp/$FILE_NAME $OUTPUT_DIR || exit 1
    $DOCKER exec $DOCKER_CONATINER rm -rf /tmp/$FILE_NAME || exit 1
  fi
}

function compress
{
  if $GZIP; then
    log "Compressing..."
    cd $OUTPUT_DIR
    $TAR -zcPf $FILE_NAME.tar.gz $FILE_PATH || exit 1
    $RM -rf $FILE_PATH || exit 1
  fi
}

function push
{
  if $PUSH_TO_GIT; then
    check_cmd $GIT
    check_git_dir $OUTPUT_DIR

    cd $OUTPUT_DIR
    $GIT add . || exit 1
    $GIT commit -m "conventional git commit "${TIME} || exit 1
    $GIT push origin master:master || exit 1
  fi
}


function main
{
  dump

  compress

  push

  $ECHO "Backup db success!"

  $ECHO "Db file will placed at ${FILE_PATH}, log has echo to ${LOG_DIR}/backup.log"

  exit 0
}

log "Begin db backup"
parse_args "$@"
main