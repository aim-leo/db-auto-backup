# db-backup documentation

## Backup script db-backup.sh

### Usage

#### Example
```
// Export the test instance of the local mongodb database to /tmp/test-db-backup
bash db-backup.sh -d test -o /tmp/test-db-backup


// Export the test database from the docker container named mysql. and compress it to the current directory
bash db-backup.sh -d test -t mysql -z

// Use the yaml file to configure and export the test database under mysql and upload it to the corresponding git
bash db-backup.sh -f example.yaml

// example.ymal
database:
  type: mysql
  name: test
  user: root
  pwd: 123456-abc
docker_container: mysql // mysql is in the docker container, the container name is mysql
output_dir: /tmp/test-db-backup
max_file: 30 // More than 30 backups will automatically delete the first backup
push2git: true // upload to git
gzip: true // Use tar to compress to .tar.gz file
git:
  remote: git@github/***/***.git // your git address, you need to create a new project on remote git
  branch: master

```

#### All parameters

```
 Usage:
     bash db-backup.sh -d [database] -o [output_dir] ...
   
   Database options: (recommand define it at yaml)
     -d | --database_name [name]                Input the database you want to dump(required)
     -t | --database_type [type]                Input the database type, enum: [mysql, mongo]
     -h | --database_host [host]                Input the database host, defalut localhost
     -p | --database_port [port]                Input the database port, defalut { mysql: 3306, mongodb: 27017 }
     -u | --database_user [user]                Input the database user, mysql is required, mongo is optional
     -s | --database_pwd  [pwd]                 Input the database pwd, mysql is required, mongo is optional
   
   Git options: (recommand define it at yaml, required when push2git set true)
     -e | --git_user_name [name]                Input the git user name, required when use http protocol
     -w | --git_user_pwd [pwd]                  Input the git user pwd, required when use http protocol
     -i | --git_user_email [email]              Input the git user email, required when use http protocol
     -r | --git_remote [remote]                 Input the git remote, accept http | ssh protocol
     -b | --git_branch [branch]                 Input the git branch, default master
   
   Optional options:
     -o | --output_dir [output_dir]             Input the dir you want to output the file, defalut current path
     -f | --config_yaml [config_yaml]           Input the yaml path contain your config, defalut at output_dir/backup.yaml
     -n | --file_name [filename]                Input the filename, default DATABASE_db_TIME
     -l | --log_dir [log_dir]                   Input the dir you want to output the log, defalut /tmp/db-backup
     -c | --docker_container [container]        If your database is runing at docker, Input the container ID or name here
     -m | --max_file [max_file]                 Expect a Number, if backup file overflow, it will auto remove the oldest file
     -g | --push2git                            Whether to auto add && commit && push to git, default false
     -z | --gzip                                Whether to gzip the dir, default false
   
   Auxiliary options:
     -h | --help                                Get help
     -v | --version                             Get current version
```
#### Parameter Description
##### -o | --output_dir [output_dir]
- Function: Specify the path of the file to be exported
- Required: An absolute path is required when using cron for automatic backup, and make sure that the directory is writable
- Default: When calling manually, the path of the current calling script is not specified

##### -f | --config_yaml [config_yaml]
- Function: Specify the yaml configuration file, it is recommended to use the yaml configuration method instead of specifying one by one
- Required: Not required, but when -d --database_name is not used, a yaml file needs to be specified and the configuration of database_name needs to be included
- Default: If not specified, the script will match the backup.yaml file in the export directory, if found, the configuration will be imported

##### -n | --file_name [filename]
- Function: Specify the name of the exported file. It is not recommended to specify this item when using cron for regular backup
- Required: Not required, and not recommended
- Default: ${DATABASE_NAME}_db_${TIME} The default is a string containing the database name and time

##### -l | --log_dir [log_dir]
- Function: Specify the log path
- Required: Not required
- Default: By default, a log file named after the current day is created under /tmp/db-backup, but when the configuration is not read, the log will be output under /tmp/db-backup/tmp.log

##### -c | --docker_container [container]
- Function: When the database is running in a docker container, specify the name or id of the container here
- Required: Not required, when not filled, the default is to connect to the local database

##### -m | --max_file [max_file]
- Function: Specify the maximum number of exported files, the script will sort by file name, when the files in the directory are greater than this value, a certain number of files will be automatically deleted, which is why it is not recommended to customize the exported file name, because Used for sorting, making sure that the program deletes the oldest backup
- Required: Not required, the number of documents is unlimited when not filled

##### -g | --push2git
- Function: whether to automatically backup to git
- Default: false

##### -z | --gzip
- Function: Whether to use tar to compress the file. When this parameter is specified, the file will be compressed into NAME.tar.gz. When decompressing, please use tar -zxvPf NAME.tar.gz
- Default: false

##### -h | --help
- Function: Get help

##### -v | --version
- Function: Get the current version

#### Database related
##### -d | --database_name [name]
- Function: Specify the database to be backed up
- Required: true (not required if specified in yaml)

##### -t | --database_type [type]
- Function: Specify the type of database to be backed up
- Optional value: mongo mysql
- Required: false
- Default value: mongo

##### -h | --database_host [host]
- Function: Specify the database address to be backed up
- Required: false
- Default value: localhost

##### -p | --database_port [port]
- Function: Specify the database port to be backed up
- Required: false
- Default value: mysql: 3306 mongo: 27017

##### -u | --database_user [user]
- Function: Specify the database user name to be backed up
- Required: Required when backing up the mysql database

##### -s | --database_pwd [pwd]
- Function: Specify the database password to be backed up
- Required: Required when backing up the mysql database

#### git options
When you specify the parameter -g, or --push2git, the script will transfer the backed up file to the specified git address. At this time, you need to specify the following parameters

Note that when using cron to automatically run this script, git cannot obtain the current ssh-keygen, but it is normal when running the script manually.This is because cron runs the script as the root user, and ssh-key is saved in the current user ( May not be root),
The backup will fail at this time, and the available solutions are:

- Specify the user's username, password and email in the script
- Generate ssk-keygen under root and add to git server

##### -e | --git_user_name [name]
- Function: Specify git username
- Required: Required when using https protocol

##### -w | --git_user_pwd [pwd]
- Function: Specify git password
- Required: Required when using https protocol

##### -i | --git_user_email [email]
- Function: Specify git mailbox
- Required: Required when using https protocol

##### -r | --git_remote [remote]
- Function: Specify git address
- Required: Required when starting backup

##### -b | --git_branch [branch]
- Function: Specify git branch
- Default value: master


## Mount automatic backup add-schedule.sh

### Usage
```
sudo bash add-schedule.sh [yaml_path] [cron_time_config]
```

We use cron to run scheduled tasks, the program is installed by default under ubuntu

The script provides an easy way to hang on scheduled tasks, you can also manually add the script to /etc/crontab, use sudo vim /etc/crontab

Make sure to use sudo to run the script. Each yaml can only be registered in the crontab at the same time. When the yaml file is registered, it will automatically overwrite the previous configuration.

##### yaml_path
- Function: Specify the backup yaml configuration file
- Required: true

##### cron_time_config
- Function: Specify the time configuration for calling the script
- Required: false
- Default: 5 * * * *" Called once every 5th minute of the hour, you can specify other configuration, refer to [cron configuration](https://crontab.guru/ "cron configuration" ), please make sure to wrap the string with ""

## Mount automatic backup delete-schedule.sh

### Usage
Delete the yaml configuration registered under crontab
```
sudo bash delete-schedule.sh [yaml_path]
```


## Sample configuration file example.yaml

```
database:
  type: mysql
  name: <database>
  user: <name>
  pwd: <pwd>
docker_container: mysql
output_dir: /home/<database>-db-backup
max_file: 30
push2git: false
gzip: true
git:
  user:
    name: <name>
    email: ***@gmail.com
    pwd: <pwd>
  remote: git@github/***/***.git
  branch: master
```

## common problem

### Why do I configure git and the file is exported normally, but it cannot be automatically submitted?

The usual reason is that the git configuration cannot be obtained, view the log, and the final output generally stops at Begin push to origin/master

When using cron to automatically run this script, git cannot get the current ssh-keygen, but it is normal when running the script manually, this is because cron runs the script as the root user, and ssh-key is saved in the current user (probably not root),
The backup will fail at this time, and the available solutions are:

Specify the username of the user in the script Password Email
```
// Specify this part in yaml:
git:
  user:
    name: <name>
    email: ***@gmail.com
    pwd: <pwd>
  remote: https://github/***/***.git (must be the git address of https protocol)
```
or
Generate ssk-keygen under root and add to git server

```
// Log in as root at the time to ensure that cron can access the ssh-key
sudo su

ssh-keygen -t rsa -C "***@gmail.com"
```
Then add the contents of /root/.ssh/id_rsa.pub to your git server's ssh-key list, refer to [connect github with ssh](https://help.github.com/en/github/authenticating-to -github/connecting-to-github-with-ssh)

### When I configure output_dir to /home/mysql-db-backup, but my git project name is mysql-db-backup2, what is the actual export directory?

output_dir specifies the final export directory, regardless of the git project name, the last exported directory is the configuration directory

When the script is run for the first time, if output_dir does not exist, it will be newly created, if git is configured, it will first pull the project, and then export the file

The export method used is

```
git clone $GIT_REMOTE $OUTPUT_DIR
```
So the last exported path is mysql-db-backup


### When I use tar -zxvf $NAME.tar.gz, why does the decompression fail?

Please use tar -zxvPf $NAME.tar.gz to unzip the file

### Why did I specify log_dir, but some output is not written to this folder?

Before the script reads the configured log_dir, the output will be written to /tmp/db-backup/tmp.log

### I specified max_file. After the number of files exceeded, why didn't the script delete the original backup?

Please check whether the file_name is specified by mistake, because the script names the file by time by default, and sorts by file name by default. When the file name is not uniform, the sorting will be messed up, please use the default naming

### What happens when I back up multiple databases to the same folder?

It is theoretically supported, but it is not recommended to do so, it is best to export a folder and a git address in a database

#### Why do I report permission errors when I run the git command in a directory everywhere?

By default, cron uses the root user to run commands. When the program is run for the first time, the program pulls the files of the remote branch, then the permissions of the directory are the highest, and ordinary users cannot operate. Please use sudo to run