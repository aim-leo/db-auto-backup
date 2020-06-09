#!/usr/bin/bash

echo=$(which echo)
pwd=$(which pwd)
mkdir=$(which mkdir)
test=$(which test)
git=$(which git)
tar=$(which tar)
mv=$(which mv)
rm=$(which rm)
touch=$(which touch)
chmod=$(which chmod)
grep=$(which grep)
eval=$(which eval)
readlink=$(which readlink)

TIME=$(date "+%Y-%m-%d_%H-%M-%S")
CURRENT=$($pwd)
PARENT_DIR="cd $CURRENT/.. && $pwd"
VERSION="1.0.2"

function usage() {
  $echo "Usage:"
  $echo "  bash mongo-backup.sh -d [database] -o [output_dir] ..."
  $echo ""
  $echo "Required options:"
  $echo "  -d | --database [database]            Input the database you want to dump(can also define it at yaml)"
  $echo ""
  $echo "Optional options:"
  $echo "  -o | --output_dir [output_dir]        Input the dir you want to output the file, defalut current path"
  $echo "  -f | --config_yaml [config_yaml]      Input the yaml path contain your config, defalut at output_dir/backup.config.yaml"
  $echo "  -n | --file_name [filename]           Input the filename, default DATABASE_db_TIME"
  $echo "  -l | --log_dir [log_dir]              Input the dir you want to output the log, defalut output_dir"
  $echo "  -c | --docker_container [container]   If your mongo is runing at docker, Input the container ID or name here"
  $echo "  -u | --docker_uri [uri]               Input the mongo uri, default is localhost:27017"
  $echo "  -m | --max_file [max_file]            Expect a Number, if backup file overflow, it will auto remove the oldest file"
  $echo "  -p | --push2git                       Whether to auto add && commit && push to git, default false"
  $echo "  -g | --gzip                           Whether to gzip the dir, default false"
  $echo ""
  $echo "Auxiliary options:"
  $echo "  -h | --help                           Get help"
  $echo "  -v | --version                        Get current version"
}

function version() {
  $echo $VERSION
}

function log() {
  FORMAT_TIME=$(date "+%Y-%m-%d %H:%M:%S")
  $echo "$FORMAT_TIME [MONGO-BACKUP] $1"
  if $test -f ${LOG_DIR}/backup.log; then
    $echo "$FORMAT_TIME [MONGO-BACKUP] $1" >>${LOG_DIR}/backup.log
  else
    $echo "$FORMAT_TIME [MONGO-BACKUP] $1" >>/tmp/backup.log
  fi
}

function ensure_dir() {
  if ! $test -d "$1"; then
    log "ensure_dir: $1 unexist, try to create it"
    $mkdir $1 || echo 'mkdir fail'
    $chmod 777 $1 || echo 'chmod fail'
    ls $1
  fi
}

function check_cmd() {
  if ! command -v $1 >/dev/null 2>&1; then
    log "check_cmd: $1 is required, please install it"
    exit 1
  fi
}

function ensure_git_dir() {
  if ! $test -d "$1"; then
    log "ensure_git_dir: $1 unexist"
  fi

  cd $1

  if [[ ! -d "$1/.git" ]]; then
    log "ensure_git_dir: $1 is not a git dir, try to init it"

    cd ..
    # $rm -rf $1
    $git clone $remote $1
    cd $1
  fi

  # check agin
  if [[ ! -d "$1/.git" ]]; then
    log "ensure_git_dir: $1 is not a git dir, and try to init it fail"

    exit 1
  fi
}

function check_number() {
  if [ "$1" -gt 0 ] 2>/dev/null; then
    return 0
  else
    return 1
  fi
}

function parse_yaml() {
  local yaml_file=$1
  local prefix=$2
  local s
  local w
  local fs
  s='[[:space:]]*'
  w='[a-zA-Z0-9_.-]*'
  fs="$(echo @ | tr @ '\034')"
  (
    sed -ne '/^--/s|--||g; s|\"|\\\"|g; s/\s*$//g;' \
      -e "/#.*[\"\']/!s| #.*||g; /^#/s|#.*||g;" \
      -e "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" \
      -e "s|^\($s\)\($w\)$s[:-]$s\(.*\)$s\$|\1$fs\2$fs\3|p" |
      awk -F"$fs" '{
            indent = length($1)/2;
            if (length($2) == 0) { conj[indent]="+";} else {conj[indent]="";}
            vname[indent] = $2;
            for (i in vname) {if (i > indent) {delete vname[i]}}
                if (length($3) > 0) {
                    vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
                    printf("%s%s%s%s=(\"%s\")\n", "'"$prefix"'",vn, $2, conj[indent-1],$3);
                }rm -rf
            }' |
      sed -e 's/_=/+=/g' \
        -e '/\..*=/s|\.|_|' \
        -e '/\-.*=/s|\-|_|'
  ) <"$yaml_file"
}
function create_variables() {
  local yaml_file="$1"
  eval "$(parse_yaml "$yaml_file")"
}

function parse_args() {
  args=()

  # named args
  while [ "$1" != "" ]; do
    case "$1" in
    -d | --database)
      DATABASE="$2"
      shift
      ;;
    -o | --output_dir)
      OUTPUT_DIR="$2"
      shift
      ;;
    -f | --yaml_config)
      YAML_PATH="$2"
      shift
      ;;
    -n | --file_name)
      FILE_NAME="$2"
      shift
      ;;
    -l | --log_dir)
      LOG_DIR="$2"
      shift
      ;;
    -c | --docker_container)
      DOCKER_CONATINER="$2"
      shift
      ;;
    -u | --docker_uri)
      DOCKER_URI="$2"
      shift
      ;;
    -m | --max-file)
      MAX_FILE="$2"
      shift
      ;;
    -p | --push2git) PUSH_TO_GIT=true ;;
    -g | --gzip) GZIP=true ;;
    -h | --help)
      usage
      exit
      ;;
    -v | --version)
      version
      exit
      ;;
    *) args+=("$1") ;;
    esac
    shift # move to next kv pair
  done

  YAML_PATH=${YAML_PATH:-$OUTPUT_DIR"/backup.yaml"}
  YAML_PATH=$($readlink -f $YAML_PATH)

  log "yaml path:"$YAML_PATH

  # first, parse the yaml config
  # the addtional option will replace the yaml config
  if $test -f "$YAML_PATH"; then
    log "Parsing yaml file at $YAML_PATH"

    create_variables $YAML_PATH

    $echo $database

    DATABASE=${DATABASE:-$database}
    DOCKER_URI=${DOCKER_URI:-$docker_uri}
    DOCKER_CONATINER=${DOCKER_CONATINER:-$docker_container}
    MAX_FILE=${MAX_FILE:-$max_file}
    PUSH_TO_GIT=${PUSH_TO_GIT:-$push2git}
    GZIP=${GZIP:-$gzip}
    MAX_FILE=${MAX_FILE:-$max_file}
    OUTPUT_DIR=${OUTPUT_DIR:-$output_dir}
  fi

  # assign default params
  GZIP=${GZIP:-false}
  PUSH_TO_GIT=${PUSH_TO_GIT:-false}
  DOCKER_URI=${DOCKER_URI:-"localhost:27017"}

  OUTPUT_DIR=${OUTPUT_DIR:-$CURRENT}
  LOG_DIR=${LOG_DIR:-$OUTPUT_DIR}

  FILE_NAME=${FILE_NAME:-$DATABASE"_db_"$TIME}

  log "config.DATABASE>> "$DATABASE
  log "config.DOCKER_URI>> "$DOCKER_URI
  log "config.DOCKER_CONATINER>> "$DOCKER_CONATINER
  log "config.MAX_FILE>> "$MAX_FILE
  log "config.PUSH_TO_GIT>> "$PUSH_TO_GIT
  log "config.GZIP>>"$GZIP
  log "config.git_user_name>> "$git_user_name
  log "config.git_user_email>> "$git_user_email
  log "config.git_user_pwd>> "$git_user_pwd
  log "config.remote>> "$remote
  log "config.OUTPUT_DIR>> "$OUTPUT_DIR
  log "config.LOG_DIR>> "$LOG_DIR
  log "config.FILE_NAME>> "$FILE_NAME

  # make sure out dir exsit
  ensure_dir $OUTPUT_DIR
  # make sure log dir exsit
  ensure_dir $LOG_DIR

  # tran to absolute path
  OUTPUT_DIR=$(cd $OUTPUT_DIR && $pwd)
  LOG_DIR=$(cd $LOG_DIR && $pwd)

  FILE_PATH=$OUTPUT_DIR/$FILE_NAME

  # if set push2git to true, set git
  set_git

  # check database
  if [[ -z "${DATABASE}" ]]; then
    log "Required database name, please input -d [database] or --database [database]"
    usage
    exit 1
  fi

  if [[ ! -z "${MAX_FILE}" ]]; then
    if ! check_number $MAX_FILE; then
      log "Max-file expected a number if seted, please recheck!"
      usage
      exit 1
    fi
  fi

  # restore positional args
  set -- "${args[@]}"
}

function set_git() {
  if $PUSH_TO_GIT; then
    check_cmd $git

    if [[ -z "${git_user_name}" ]]; then
      log "Expected a git user name"
      exit 1
    fi

    if [[ -z "${git_user_email}" ]]; then
      log "Expected a git user email"
      exit 1
    fi

    if [[ -z "${git_user_pwd}" ]]; then
      log "Expected a git user pwd"
      exit 1
    fi

    if [[ -z "${git_remote}" ]]; then
      log "Expected a git remote"
      exit 1
    fi

    remote="https://$git_user_name:$git_user_pwd@$git_remote"
    git_branch=${git_branch:-"master"}

    log "Checking weather the dir is a git dir"
    ensure_git_dir $OUTPUT_DIR

    cd $OUTPUT_DIR
    log "Setting git user config"
    $git config user.name $git_user_name
    $git config user.email $git_user_email
  fi
}

function dump() {
  log "Begin dump file"
  if [[ -z "${DOCKER_CONATINER}" ]]; then
    log "Use local mongodump cmd"
    mongodump=$(which mongodump)
    check_cmd $mongodump

    $mongodump -h $DOCKER_URI -d $DATABASE -o $FILE_PATH || exit 1
  else
    log "Use docker mongodump cmd"

    docker=$(which docker)
    check_cmd $docker

    log "Begin exec dump cmd in docker"
    $docker exec $DOCKER_CONATINER /bin/bash -c "/usr/bin/mongodump -h $DOCKER_URI -d $DATABASE -o /tmp/$FILE_NAME" >>${LOG_DIR}/backup.log || exit 1
    log "Begin cp file out of docker"
    $docker cp $DOCKER_CONATINER:/tmp/$FILE_NAME $OUTPUT_DIR >>${LOG_DIR}/backup.log || exit 1
    log "Begin rm useless dump file in docker"
    $docker exec $DOCKER_CONATINER rm -rf /tmp/$FILE_NAME >>${LOG_DIR}/backup.log || exit 1
  fi
  log "Dump file complete"
}

function clean() {
  if [[ ! -z "${MAX_FILE}" ]]; then
    log "Begin clean redundant file"

    COUNT=$(ls $OUTPUT_DIR -tr | $grep $DATABASE"_db" | wc -l)

    log "There is $COUNT db file at $OUTPUT_DIR, max file is $MAX_FILE"

    if [ "$MAX_FILE" -lt "$COUNT" ]; then
      NAMES=$(ls $OUTPUT_DIR -tr | $grep $DATABASE)
      LIST=(${NAMES/ /})

      OVERFLOW_NUM=$(expr $COUNT - $MAX_FILE)

      log "Should rm $OVERFLOW_NUM of dir: $OUTPUT_DIR"

      INDEX=0
      for i in ${LIST[@]}; do
        if [ "$INDEX" -lt "$OVERFLOW_NUM" ]; then
          log "rm file: $OUTPUT_DIR/$i"
          $rm -rf $OUTPUT_DIR/$i

          let INDEX+=1
        fi
      done
    fi

    log "Clean redundant file complete"
  fi
}

function compress() {
  if $GZIP; then
    log "Begin compress file"
    cd $OUTPUT_DIR
    log "Begin tar file: $FILE_PATH to $FILE_NAME.tar.gz, When you extract, Please use cmd: $tar -zxPf $FILE_NAME.tar.gz"
    $tar -zcPf $FILE_NAME.tar.gz $FILE_PATH || exit 1
    log "Begin rm old file: $FILE_PATH"
    $rm -rf $FILE_PATH || exit 1
    log "Compress file complete"
  fi
}

function push() {
  if $PUSH_TO_GIT; then
    log "Begin push file to git"
    cd $OUTPUT_DIR

    log "Pulling all commit at this dir"
    $git pull $remote $git_branch >>${LOG_DIR}/backup.log
    log "Adding all change at this dir"
    $git add . >>${LOG_DIR}/backup.log || exit 1
    log "Adding a commit"
    $git commit -m "conventional commit $TIME" >>${LOG_DIR}/backup.log || exit 1
    log "Begin push to origin/master"
    $git push $remote $git_branch >>${LOG_DIR}/backup.log || exit 1
    # reset head to origin/master
    $git push origin master
    log "Push file complete"
  fi
}

function main() {
  dump

  clean

  compress

  push

  log "Backup db success!"

  log "Db file will placed at ${FILE_PATH}, log has echo to ${LOG_DIR}/backup.log"

  exit 0
}

parse_args "$@"
main