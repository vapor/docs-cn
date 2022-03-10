# 什么是Heroku

Heroku是一个流行的一体化托管解决方案，你可以在[heroku.com](https://www.heroku.com)找到更多信息。

## 注册

你需要一个heroku账户，如果你没有，请在这里注册：[https://signup.heroku.com/](https://signup.heroku.com/)

## 安装CLI

确保你已经安装了heroku cli工具。

### HomeBrew

```bash
brew install heroku/brew/heroku
```

### 其他安装选项

请参阅这里的其他安装选项：[https://devcenter.heroku.com/articles/heroku-cli#download-and-install](https://devcenter.heroku.com/articles/heroku-cli#download-and-install)。

### 登录

一旦你安装了cli，用以下方式登录：

```bash
heroku login
```

验证正确的电子邮件是否已登录：

```bash
heroku auth:whoami
```

###创建一个应用程序

访问dashboard.heroku.com访问你的账户，从右上角的下拉菜单中创建一个新的应用程序。Heroku会问一些问题，如地区和应用程序的名称，按照他们的提示进行操作即可。

### Git

Heroku使用Git来部署你的应用程序，所以你需要把你的项目放入Git仓库，如果它还没有的话。

#### 安装Git

如果你需要将Git添加到你的项目中，在终端输入以下命令：

```bash
git init
```

#### Master

默认情况下，Heroku部署的是**master**分支。在推送之前，请确保所有的修改都检查到这个分支。

用以下方法检查你的当前分支

```bash
git branch
```

`*`号表示当前分支。

```bash
* master
  commander
  other-branches
```

!!! note 
    如果你没有看到任何输出，而且你刚刚执行了`git init`。你需要先提交你的代码，然后你会看到`git branch`命令的输出。


如果你目前不在**master**上，可以通过输入来切换到那里：

```bash
git checkout master
```

#### 提交更改

如果这个命令产生输出，那么你有未提交的修改。

```bash
git status --porcelain
```

用下面的命令提交它们

```bash
git add .
git commit -m "a description of the changes I made"
```

#### 与Heroku连接

将你的应用程序与heroku连接起来（用你的应用程序的名称代替）。

```bash
$ heroku git:remote -a your-apps-name-here
```

### 设置Buildpack

设置buildpack来教heroku如何处理Vapor。

```bash
heroku buildpacks:set vapor/vapor
```

### Swift 版本文件

我们添加的 buildpack 会寻找一个 **.swift-version** 文件，以了解要使用哪个版本的 swift。(用你的项目需要的任何版本替换5.2.1)。

```bash
echo "5.2.1" > .swift-version
```

这将创建**.swift-version**为`5.2.1`的内容。


### Procfile

Heroku使用**Procfile**来知道如何运行你的应用程序，在我们的例子中，它需要看起来像这样：

```
web: Run serve --env production --hostname 0.0.0.0 --port $PORT
```

我们可以用下面的终端命令来创建它

```bash
echo "web: Run serve --env production" \
  "--hostname 0.0.0.0 --port \$PORT" > Procfile
```

### 提交修改

我们刚刚添加了这些文件，但它们还没有提交。如果我们推送，heroku将找不到它们。

用下面的方法提交它们。

```bash
git add .
git commit -m "adding heroku build files"
```

### 部署到Heroku

你已经准备好部署了，从终端运行这个。它可能需要一些时间来构建，这是正常的。

```none
git push heroku master
```

### 扩大规模

一旦你建立成功，你需要添加至少一个服务器，一个网络是免费的，你可以通过以下方式获得它。

```bash
heroku ps:scale web=1
```

### 继续部署

任何时候你想更新，只需将最新的变化放入主目录并推送到heroku，它就会重新部署。

## Postgres

### 添加PostgreSQL数据库

访问你在dashboard.heroku.com的应用程序，进入**附加组件**部分。

在这里输入`postgress`，你会看到一个`Heroku Postgres`的选项。选择它。

选择爱好开发的免费计划，然后提供。Heroku会做其他事情。

一旦你完成，你会看到数据库出现在**资源**标签下。

### 配置数据库

我们现在必须告诉我们的应用程序如何访问数据库。在我们的应用程序目录中，让我们运行。

```bash
heroku config
```

这将使输出有点像这样

```none
=== today-i-learned-vapor Config Vars
DATABASE_URL: postgres://cybntsgadydqzm:2d9dc7f6d964f4750da1518ad71hag2ba729cd4527d4a18c70e024b11cfa8f4b@ec2-54-221-192-231.compute-1.amazonaws.com:5432/dfr89mvoo550b4
```

**DATABASE_URL**这里将代表postgres数据库。**千万**不要在这里硬编码静态URL，heroku会旋转它，这将破坏你的应用程序。这也是不好的做法。

下面是一个数据库配置的例子

```swift
if let databaseURL = Environment.get("DATABASE_URL") {
    app.databases.use(try .postgres(
        url: databaseURL
    ), as: .psql)
} else {
    // ...
}
```

如果你使用Heroku Postgres的标准计划，则需要未验证的TLS：

```swift
if let databaseURL = Environment.get("DATABASE_URL"), var postgresConfig = PostgresConfiguration(url: databaseURL) {
    postgresConfig.tlsConfiguration = .makeClientConfiguration()
    postgresConfig.tlsConfiguration?.certificateVerification = .none
    app.databases.use(.postgres(
        configuration: postgresConfig
    ), as: .psql)
} else {
    // ...
}
```

不要忘记提交这些修改

```none
git add .
git commit -m "configured heroku database"
```

### 恢复你的数据库

你可以用`run`命令恢复或运行heroku上的其他命令。Vapor的项目默认也被命名为`Run`，所以它的读法有点奇怪。

要恢复你的数据库：

```bash
heroku run Run -- migrate --revert --all --yes --env production
```

要迁移

```bash
heroku run Run -- migrate --env production
```
