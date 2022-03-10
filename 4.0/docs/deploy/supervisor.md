# Supervisor

[Supervisor](http://supervisord.org)是一个过程控制系统，可以轻松启动、停止和重新启动Vapor应用程序。

## 安装

Supervisor可以通过Linux上的软件包管理器安装。

### Ubuntu

```sh
sudo apt-get update
sudo apt-get install supervisor
```

### CentOS和Amazon Linux

```sh
sudo yum install supervisor
```

### Fedora

```sh
sudo dnf install supervisor
```

## 配置

你服务器上的每个Vapor应用都应该有自己的配置文件。以`Hello`项目为例，该配置文件位于`/etc/supervisor/conf.d/hello.conf`。

```sh
[program:hello]
command=/home/vapor/hello/.build/release/Run serve --env production
directory=/home/vapor/hello/
user=vapor
stdout_logfile=/var/log/supervisor/%(program_name)-stdout.log
stderr_logfile=/var/log/supervisor/%(program_name)-stderr.log
```

正如我们的配置文件中所指定的，`Hello`项目位于用户`vapor`的主文件夹中。确保`directory`指向你项目的根目录，即`Package.swift`文件所在的目录。

`--env production`标志将禁用粗略的日志记录。

###环境

你可以用supervisor向你的Vapor应用程序导出变量。如果要导出多个环境值，请把它们都放在一行。根据[Supervisor文档](http://supervisord.org/configuration.html#program-x-section-values)。

> 含有非字母数字字符的值应该加引号（例如：KEY="val:123",KEY2="val,456"）。否则，值的引号是可选的，但推荐使用。

```sh
environment=PORT=8123,ANOTHERVALUE="/something/else"
```

输出的变量可以在Vapor中使用`Environment.get`。

```swift
let port = Environment.get("PORT")
```

## 开始

现在你可以加载并启动你的应用程序。

```sh
supervisorctl reread
supervisorctl add hello
supervisorctl start hello
```

!!! note
    `add`命令可能已经启动了你的应用程序。
