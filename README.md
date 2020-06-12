# db-backup说明文档

## 备份脚本 db-backup.sh

### 用法

#### 示例
```
// 将本地的mongodb数据库的test实例导出到/tmp/test-db-backup下
bash db-backup.sh -d test -o /tmp/test-db-backup


// 从名称为mysql的docker容器内导出test数据库.并压缩,到当前目录
bash db-backup.sh -d test -t mysql -z

// 使用yaml文件配置导出mysql下test数据库,并上传到对应的git
bash db-backup.sh -f example.yaml

// example.ymal
database:
  type: mysql
  name: test
  user: root
  pwd: 123456-abc
docker_container: mysql  // mysql在docker容器中,容器名是mysql
output_dir: /tmp/test-db-backup
max_file: 30    // 超过30个备份自动删除最开始的备份
push2git: true  // 上传到git
gzip: true   // 用tar压缩成.tar.gz文件
git:
  remote: git@github/***/***.git  // 你的git地址,需要在远程git上新建项目
  branch: master

```

#### 所有参数

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
#### 参数说明
##### -o | --output_dir [output_dir]
- 作用: 指定要导出文件的路径
- 必填: 使用cron自动备份时必填一个绝对路径,且确保该目录可写
- 默认: 当手动调用时,未指定则为当前调用脚本的路径

##### -f | --config_yaml [config_yaml]
- 作用: 指定yaml配置文件, 推荐使用yaml配置的方式而不是逐个指定
- 必填: 非必填,但当未使用-d --database_name时,需要指定一个yaml文件,且需要包含database_name的配置
- 默认: 如果未指定,脚本会在导出目录下匹配backup.yaml文件,如果找到将导入该配置

##### -n | --file_name [filename]
- 作用: 指定导出的文件名,当使用cron定时备份时不推荐指定该项
- 必填: 非必填, 且不推荐填写
- 默认: ${DATABASE_NAME}_db_${TIME} 默认是包含数据库明和时间的字串

##### -l | --log_dir [log_dir]
- 作用: 指定日志路径
- 必填: 非必填
- 默认: 默认在/tmp/db-backup下创建一个以当天日期命名的log文件,但是当该配置未读取前,日志将会输出在/tmp/db-backup/tmp.log下

##### -c | --docker_container [container]
- 作用: 当数据库运行在docker容器里时,在这里指定容器的name或者id
- 必填: 非必填,当不填是默认连接本地数据库

##### -m | --max_file [max_file]
- 作用: 指定导出文件的最多数量,脚本会按照文件名称排序,当目录下的文件大于该值,会自动删除一定数量的文件,这也是为什么不推荐自定义导出的文件名的原因,因为要用于排序,确保程序删除的是最老的备份
- 必填: 非必填,当不填写时文件数目无限制

##### -g | --push2git
- 作用: 是否自动备份到git
- 默认: false

##### -z | --gzip
- 作用: 是否使用tar来压缩文件,当指定该参数,文件将会压缩成NAME.tar.gz, 解压缩时,请使用 tar -zxvPf NAME.tar.gz
- 默认: false

##### -h | --help
- 作用: 获取帮助

##### -v | --version
- 作用: 获取当前版本

#### 数据库相关
##### -d | --database_name [name]
- 作用: 指定要备份的数据库
- 必填: true(如果在yaml中指定了可不填)

##### -t | --database_type [type]
- 作用: 指定要备份的数据库类型
- 可选值: mongo mysql
- 必填: false
- 默认值: mongo

##### -h | --database_host [host]
- 作用: 指定要备份的数据库地址
- 必填: false
- 默认值: localhost

##### -p | --database_port [port]
- 作用: 指定要备份的数据库端口
- 必填: false
- 默认值: mysql: 3306 mongo: 27017

##### -u | --database_user [user]
- 作用: 指定要备份的数据库用户名
- 必填: 当备份mysql数据库时必填

##### -s | --database_pwd  [pwd]
- 作用: 指定要备份的数据库密码
- 必填: 当备份mysql数据库时必填

#### GIT相关
当指定参数-g,或者--push2git时,脚本会把备份后的文件传到指定的git地址,此时需要指定以下参数

注意, 当使用cron自动运行此脚本时, git无法获取到当前的ssh-keygen,而手动运行脚本时则正常,这是因为cron是以root用户身份运行脚本,而ssh-key保存在当前用户(可能不是root)下,
此时备份会失败,可选的解决办法有:

- 在脚本中指定用户的用户名 密码 邮箱
- 在root下生成ssk-keygen,并添加到git服务器

##### -e | --git_user_name [name]
- 作用: 指定git用户名
- 必填: 当使用https协议时必填

##### -w | --git_user_pwd [pwd]
- 作用: 指定git密码
- 必填: 当使用https协议时必填

##### -i | --git_user_email [email]
- 作用: 指定git邮箱
- 必填: 当使用https协议时必填

##### -r | --git_remote [remote]
- 作用: 指定git地址
- 必填: 开启备份时必填

##### -b | --git_branch [branch]
- 作用: 指定git分支
- 默认值: master


## 挂载自动备份 add-schedule.sh

### 用法
```
sudo bash add-schedule.sh [yaml_path] [cron_time_config]
```

我们使用cron来运行定时任务,该程序在ubuntu下默认安装

该脚本提供简单的方法来挂在定时任务,你也可以手动添加脚本到/etc/crontab下,使用sudo vim /etc/crontab

确保使用sudo运行该脚本, 每个yaml只能在crontab中同时注册一次,当该yaml文件已注册时,会自动覆盖之前的配置

##### yaml_path
- 作用: 指定备份的yaml配置文件
- 必填: true

##### cron_time_config
- 作用: 指定调用脚本的时间配置
- 必填: false
- 默认: 5 * * * *" 每个小时的第5分钟调用一次,你可以指定其他的配置,参考[cron配置](http://www.bejson.com/othertools/cron/ "cron配置"),请确保使用""包裹该字串

## 挂载自动备份 delete-schedule.sh

### 用法
删除已注册在crontab下的yaml配置
```
sudo bash delete-schedule.sh [yaml_path]
```


## 配置文件示例 example.yaml

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

## 常见问题

### 为什么我配置了git,文件也正常导出了,但是不能自动提交?

通常的原因是无法获取到git配置,查看log, 最后的输出一般停在Begin push to origin/master

当使用cron自动运行此脚本时, git无法获取到当前的ssh-keygen,而手动运行脚本时则正常,这是因为cron是以root用户身份运行脚本,而ssh-key保存在当前用户(可能不是root)下,
此时备份会失败,可选的解决办法有:

在脚本中指定用户的用户名 密码 邮箱
```
// 在yaml中指定这部分:
git:
  user:
    name: <name>
    email: ***@gmail.com
    pwd: <pwd>
  remote: https://github/***/***.git (必须是https协议的git地址)
```
或者
在root下生成ssk-keygen,并添加到git服务器

```
// 以root当时登录,确保cron可访问到ssh-key
sudo su

ssh-keygen -t rsa -C "***@gmail.com"
```
然后将/root/.ssh/id_rsa.pub的内容添加到你的git服务器的ssh-key列表, 参考[connect github with ssh](https://help.github.com/en/github/authenticating-to-github/connecting-to-github-with-ssh)

### 当我配置output_dir为/home/mysql-db-backup, 但我的git项目名是mysql-db-backup2时,实际导出目录是什么?

output_dir指定的就是最终导出目录,不管git的项目名称是什么,最后导出的目录就是配置目录

在脚本首次运行时,如果output_dir不存在,则会新建它,如果配置了git,则会首先拉取该项目,然后再导出文件

使用的导出方法是

```
git clone $GIT_REMOTE $OUTPUT_DIR
```
所以最后导出的路径是mysql-db-backup


### 当我使用tar -zxvf $NAME.tar.gz时,为什么会解压失败?

请使用tar -zxvPf $NAME.tar.gz来解压文件

### 为什么我指定了log_dir,但是某些输出没有写到该文件夹下?

在脚本未读取到配置的log_dir前, 输出的内容将被写到/tmp/db-backup/tmp.log下

### 我指定了max_file,到文件数量超过之后,为什么脚本并没有删除最原始的备份?

请检查是否错误指定了file_name,因为脚本默认以时间命名文件,默认以文件名排序,当文件名不统一时,排序将会混乱,请使用默认命名

### 当我把多个数据库备份到同一个文件夹会怎么样?

理论上是支持的, 倒是不推荐这么做, 最好是一个数据库一个导出文件夹,一个git地址

#### 为什么我在到处的目录下运行git命令,会报权限错误?

cron默认用root用户来运行命令, 当首次运行时, 程序拉取了远程分支的文件, 则该目录的权限为最高,普通用户无法操作,请使用sudo来运行