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
touch=$(which touch)

TIME=$(date "+%Y-%m-%d_%H-%M-%S")
DAY=$(date "+%Y-%m-%d")
CURRENT=$($pwd)
PARENT_DIR="cd $CURRENT/.. && $pwd"
VERSION="1.0.3"

function usage() {
  $echo "Usage:"
  $echo "  bash db-backup.sh -d [database] -o [output_dir] ..."
  $echo ""
  $echo "Database options: (recommand define it at yaml)"
  $echo "  -d | --database_name [name]           Input the database you want to dump(required)"
  $echo "  -t | --database_type [type]           Input the database type, enum: [mysql, mongo]"
  $echo "  -h | --database_host [host]           Input the database host, defalut localhost"
  $echo "  -p | --database_port [port]           Input the database port, defalut { mysql: 3306, mongodb: 27017 }"
  $echo "  -u | --database_user [user]           Input the database user, mysql is required, mongo is optional"
  $echo "  -s | --database_pwd  [pwd]            Input the database pwd, mysql is required, mongo is optional"
  $echo ""
  $echo "Git options: (recommand define it at yaml, required when push2git set true)"
  $echo "  -e | --git_user_name [name]           Input the git user name"
  $echo "  -w | --git_user_pwd [pwd]             Input the git user pwd"
  $echo "  -i | --git_user_email [email]         Input the git user email"
  $echo "  -r | --git_remote [remote]            Input the git remote"
  $echo "  -b | --git_branch [branch]            Input the git branch"
  $echo ""
  $echo "Optional options:"
  $echo "  -o | --output_dir [output_dir]        Input the dir you want to output the file, defalut current path"
  $echo "  -f | --config_yaml [config_yaml]      Input the yaml path contain your config, defalut at output_dir/backup.yaml"
  $echo "  -n | --file_name [filename]           Input the filename, default DATABASE_db_TIME"
  $echo "  -l | --log_dir [log_dir]              Input the dir you want to output the log, defalut /tmp/db-backup"
  $echo "  -c | --docker_container [container]   If your database is runing at docker, Input the container ID or name here"
  $echo "  -m | --max_file [max_file]            Expect a Number, if backup file overflow, it will auto remove the oldest file"
  $echo "  -g | --push2git                       Whether to auto add && commit && push to git, default false"
  $echo "  -z | --gzip                           Whether to gzip the dir, default false"
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
  $echo "$FORMAT_TIME [MONGO-BACKUP] $*"
  if $test ! -z $LOG_PATH && $test -f $LOG_PATH; then
    $echo "$FORMAT_TIME [MONGO-BACKUP] $*" >>$LOG_PATH
  else
    $echo "$FORMAT_TIME [MONGO-BACKUP] $*" >>/tmp/db-backup/tmp.log
  fi
}

function ensure_dir() {
  if $test ! -d "$1"; then
    log "ensure_dir: $1 unexist, try to create it"
    $mkdir $1 || echo 'mkdir fail'
    $chmod 777 $1 || echo 'chmod fail'
  fi
}

function ensure_file() {
  local file_path=$1"/"$2
  if $test ! -f "$file_path"; then
    log "ensure_file: $2 unexist at $1, try to create it"

    ensure_dir $1

    $touch $file_path || echo 'touch fail'
    $chmod 777 $file_path || echo 'chmod fail'
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
    $git clone $GIT_REMOTE $1
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
    -d | --database_name)
      DATABASE_NAME="$2"
      shift
      ;;
    -t | --database_type)
      DATABASE_TYPE="$2"
      shift
      ;;
    -u | --database_user)
      DATABASE_USER="$2"
      shift
      ;;
    -s | --database_pwd)
      DATABASE_PWD="$2"
      shift
      ;;
    -h | --database_host)
      DATABASE_HOST="$2"
      shift
      ;;
    -p | --database_port)
      DATABASE_PORT="$2"
      shift
      ;;
    -e | --git_user_name)
      GIT_USER_NAME="$2"
      shift
      ;;
    -w | --git_user_pwd)
      GIT_USER_PWD="$2"
      shift
      ;;
    -i | --git_user_email)
      GIT_USER_EMAIL="$2"
      shift
      ;;
    -r | --git_remote)
      GIT_REMOTE="$2"
      shift
      ;;
    -b | --git_branch)
      GIT_BRANCH="$2"
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
    -m | --max-file)
      MAX_FILE="$2"
      shift
      ;;
    -g | --push2git) PUSH_TO_GIT=true ;;
    -z | --gzip) GZIP=true ;;
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

  $echo "Yaml path: $YAML_PATH"

  # first, parse the yaml config
  # the addtional option will replace the yaml config
  if $test -f "$YAML_PATH"; then
    $echo "Parsing yaml file at $YAML_PATH"

    create_variables $YAML_PATH

    DATABASE_NAME=${DATABASE_NAME:-$database_name}
    DATABASE_TYPE=${DATABASE_TYPE:-$database_type}
    DATABASE_USER=${DATABASE_USER:-$database_user}
    DATABASE_PWD=${DATABASE_PWD:-$database_pwd}
    DATABASE_HOST=${DATABASE_HOST:-$database_host}
    DATABASE_PORT=${DATABASE_PORT:-$database_port}

    GIT_USER_NAME=${GIT_USER_NAME:-$git_user_name}
    GIT_USER_PWD=${GIT_USER_PWD:-$git_user_pwd}
    GIT_USER_EMAIL=${GIT_USER_EMAIL:-$git_user_email}
    GIT_REMOTE=${GIT_REMOTE:-$git_remote}
    GIT_BRANCH=${GIT_BRANCH:-$git_branch}

    DOCKER_CONATINER=${DOCKER_CONATINER:-$docker_container}

    MAX_FILE=${MAX_FILE:-$max_file}
    PUSH_TO_GIT=${PUSH_TO_GIT:-$push2git}
    GZIP=${GZIP:-$gzip}

    OUTPUT_DIR=${OUTPUT_DIR:-$output_dir}
    LOG_DIR=${LOG_DIR:-$log_dir}
  fi

  # assign default params
  GZIP=${GZIP:-false}
  PUSH_TO_GIT=${PUSH_TO_GIT:-false}
  DATABASE_TYPE=${DATABASE_TYPE:-"mongo"}
  DATABASE_HOST=${DATABASE_HOST:-"localhost"}
  GIT_BRANCH=${GIT_BRANCH:-"master"}
  LOG_DIR=${LOG_DIR:-"/tmp/db-backup"}

  OUTPUT_DIR=${OUTPUT_DIR:-$CURRENT}

  FILE_NAME=${FILE_NAME:-$DATABASE_NAME"_db_"$TIME}
  LOG_PATH=${LOG_DIR}"/backup-$DAY.log"

  # assign default db host
  if $test "mongo" == "$DATABASE_TYPE"; then
    DATABASE_PORT=${DATABASE_PORT:-"27017"}
  else
    DATABASE_PORT=${DATABASE_PORT:-"3306"}
    FILE_NAME="$FILE_NAME.sql"
  fi

  # make sure out dir exsit
  ensure_dir $OUTPUT_DIR
  # make sure log dir exsit
  ensure_dir $LOG_DIR

  # tran to absolute path
  OUTPUT_DIR=$(cd $OUTPUT_DIR && $pwd)
  LOG_DIR=$(cd $LOG_DIR && $pwd)

  FILE_PATH=$OUTPUT_DIR/$FILE_NAME

  ensure_file $LOG_DIR backup-$DAY.log

  log "-----------------------------------------START SPLIT LINE-----------------------------------------------"
  log "config.DATABASE_NAME>> "$DATABASE_NAME
  log "config.DATABASE_TYPE>> "$DATABASE_TYPE
  log "config.DATABASE_USER>> "$DATABASE_USER
  log "config.DATABASE_PWD>> "$DATABASE_PWD
  log "config.DATABASE_HOST>> "$DATABASE_HOST
  log "config.DOCKER_CONATINER>> "$DOCKER_CONATINER
  log "config.MAX_FILE>> "$MAX_FILE
  log "config.PUSH_TO_GIT>> "$PUSH_TO_GIT
  log "config.GZIP>>"$GZIP
  log "config.GIT_USER_NAME>> "$GIT_USER_NAME
  log "config.GIT_USER_EMAIL>> "$GIT_USER_EMAIL
  log "config.GIT_USER_PWD>> "$GIT_USER_PWD
  log "config.GIT_REMOTE>> "$remote
  log "config.OUTPUT_DIR>> "$OUTPUT_DIR
  log "config.LOG_PATH>> "$LOG_PATH
  log "config.FILE_NAME>> "$FILE_NAME

  # if set push2git to true, set git
  set_git

  # check database
  if [[ -z "${DATABASE_NAME}" ]]; then
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

    is_ssh_git=`$echo $GIT_REMOTE | $grep @`

    # if not a ssh git, must define the user name & pwd
    if [[ -z "${is_ssh_git}" ]]; then
      if [[ -z "${GIT_USER_NAME}" ]]; then
        log "Expected a git user name"
        exit 1
      fi

      if [[ -z "${GIT_USER_PWD}" ]]; then
        log "Expected a git user email"
        exit 1
      fi

      if [[ -z "${GIT_USER_EMAIL}" ]]; then
        log "Expected a git user pwd"
        exit 1
      fi

      if [[ -z "${GIT_REMOTE}" ]]; then
        log "Expected a git remote"
        exit 1
      fi

      # replace http https
      GIT_REMOTE=`$echo $GIT_REMOTE | sed "s/https\?:\/\///g"`
      GIT_REMOTE="https://$GIT_USER_NAME:$GIT_USER_PWD@$GIT_REMOTE"
    fi

    log "Checking weather the dir is a git dir"
    ensure_git_dir $OUTPUT_DIR

    cd $OUTPUT_DIR
    if [[ ! -z "${GIT_USER_NAME}" ]]; then
      log "Setting git user name to "$GIT_USER_NAME
      $git config user.name $GIT_USER_NAME
    fi

    if [[ ! -z "${GIT_USER_EMAIL}" ]]; then
      log "Setting git user email to "$GIT_USER_EMAIL
      $git config user.email $GIT_USER_EMAIL
    fi
  fi
}

function dump() {
  if $test "mongo" == "$DATABASE_TYPE"; then
    mongo_dump
  else
    mysql_dump
  fi
}

function mongo_dump() {
  log "Begin dump mongodb file"

  local database_address=$DATABASE_HOST":"$DATABASE_PORT

  if [[ -z "${DOCKER_CONATINER}" ]]; then
    log "Use local mongodump cmd"
    local mongodump=$(which mongodump)
    check_cmd $mongodump

    $mongodump -h $database_address -d $DATABASE_NAME -o $FILE_PATH || exit 1
  else
    log "Use docker mongodump cmd"

    local docker=$(which docker)
    check_cmd $docker

    log "Begin exec dump cmd in docker"
    $docker exec $DOCKER_CONATINER /bin/bash -c "/usr/bin/mongodump -h $database_address -d $DATABASE_NAME -o /tmp/$FILE_NAME" >>$LOG_PATH || exit 1
    log "Begin cp file out of docker"
    $docker cp $DOCKER_CONATINER:/tmp/$FILE_NAME $OUTPUT_DIR >>$LOG_PATH || exit 1
    log "Begin rm useless dump file in docker"
    $docker exec $DOCKER_CONATINER rm -rf /tmp/$FILE_NAME >>$LOG_PATH || exit 1
  fi
  log "Dump file complete"
}

function mysql_dump() {
  log "Begin dump mysql file"
  log "Checking mysql user"

  if [[ -z "${DATABASE_USER}" ]]; then
    log "Please input you mysql user name"
    exit 1
  fi

  if [[ -z "${DATABASE_PWD}" ]]; then
    log "Please input you mysql user pwd"
    exit 1
  fi

  if [[ -z "${DOCKER_CONATINER}" ]]; then
    local mysqldump=$(which mysqldump)
    check_cmd $mysqldump

    $mysqldump -h$DATABASE_HOST -P$DATABASE_PORT -u$DATABASE_USER -p$DATABASE_PWD $DATABASE_NAME >$FILE_PATH || exit 1
  else
    log "Use docker mysqldump cmd"

    local docker=$(which docker)
    check_cmd $docker

    log "Begin exec dump cmd in docker"
    $docker exec $DOCKER_CONATINER bash -c "/usr/bin/mysqldump -h$DATABASE_HOST -P$DATABASE_PORT -u$DATABASE_USER -p$DATABASE_PWD $DATABASE_NAME > /tmp/$FILE_NAME" >>$LOG_PATH || exit 1
    log "Begin cp file out of docker"
    $docker cp $DOCKER_CONATINER:/tmp/$FILE_NAME $OUTPUT_DIR >>$LOG_PATH || exit 1
    log "Begin rm useless dump file in docker"
    $docker exec $DOCKER_CONATINER rm -rf /tmp/$FILE_NAME >>$LOG_PATH || exit 1
  fi
  log "Dump file complete"
}

function clean() {
  if [[ ! -z "${MAX_FILE}" ]]; then
    log "Begin clean redundant file"

    local count=$(ls $OUTPUT_DIR | $grep $DATABASE_NAME"_db" | wc -l)

    log "There is $count db file at $OUTPUT_DIR, max file is $MAX_FILE"

    if [ "$MAX_FILE" -lt "$count" ]; then
      local names=$(ls $OUTPUT_DIR | $grep $DATABASE_NAME"_db")
      local list=(${names/ /})
      log $list

      local overflow_num=$(expr $count - $MAX_FILE)

      log "Should rm $overflow_num of dir: $OUTPUT_DIR"

      local index=0
      for i in ${list[@]}; do
        if [ "$index" -lt "$overflow_num" ]; then
          log "rm file: $OUTPUT_DIR/$i"
          $rm -rf $OUTPUT_DIR/$i

          let index+=1
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
    log "Begin tar file: $FILE_PATH to $FILE_NAME.tar.gz"
    log "When you extract, Please use cmd: $tar -zxPf $FILE_NAME.tar.gz"
    $tar -zcPf $FILE_NAME.tar.gz $FILE_PATH >>$LOG_PATH || exit 1
    log "Begin rm old file: $FILE_PATH"
    $rm -rf $FILE_PATH>>$LOG_PATH || exit 1
    log "Compress file complete"
  fi
}

function push() {
  if $PUSH_TO_GIT; then
    log "Begin push file to git"
    cd $OUTPUT_DIR

    if [[ -z "$is_ssh_git" ]]; then
      local remote=$GIT_REMOTE
    else
      local remote="origin"
    fi

    log "Pulling all commit at this dir, remote: "$remote
    $git pull $remote $GIT_BRANCH >>$LOG_PATH
    log "Adding all change at this dir"
    $git add . >>$LOG_PATH || exit 1
    log "Adding a commit"
    $git commit -m "conventional commit $TIME" >>$LOG_PATH || exit 1
    log "Begin push to origin/master"
    $git push $remote $GIT_BRANCH >>$LOG_PATH || exit 1
    log "Push file complete"
  fi
}

function main() {
  dump

  clean

  compress

  push

  log "Db file has placed at ${FILE_PATH}, log has echo to $LOG_PATH"

  log "Backup db success!"

  exit 0
}

ensure_file /tmp/db-backup tmp.log

parse_args "$@"
main