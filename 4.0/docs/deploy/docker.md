# Docker部署

使用Docker来部署你的Vapor应用程序有几个好处。

1. 你的docker化应用可以在任何有Docker Daemon的平台上使用相同的命令可靠地启动，即Linux（CentOS、Debian、Fedora、Ubuntu）、macOS和Windows。
2. 你可以使用docker-compose或Kubernetes清单来协调全面部署所需的多个服务（如Redis、Postgres、nginx等）。
3. 3.很容易测试你的应用程序的水平扩展能力，即使是在你的开发机器上也是如此。

本指南将不再解释如何将你的docker化应用放到服务器上。最简单的部署是在服务器上安装Docker，并在开发机上运行相同的命令来启动你的应用程序。

更复杂和强大的部署通常取决于你的托管解决方案；许多流行的解决方案，如AWS，都有对Kubernetes和自定义数据库解决方案的内置支持，这使得我们很难以适用于所有部署的方式来编写最佳实践。

尽管如此，使用Docker将整个服务器堆栈旋转到本地进行测试，对于大型和小型的服务器端应用程序来说都是非常有价值的。此外，本指南中描述的概念大致适用于所有的Docker部署。

## 设置

你需要设置你的开发环境来运行Docker，并对配置Docker堆栈的资源文件有一个基本的了解。

### 安装Docker

你将需要为你的开发者环境安装Docker。你可以在Docker引擎概述的[支持平台](https://docs.docker.com/install/#supported-platforms)部分找到任何平台的信息。如果你使用的是Mac OS，你可以直接跳到[Docker for Mac](https://docs.docker.com/docker-for-mac/install/)安装页面。

###生成模板

我们建议使用Vapor模板作为一个起点。如果你已经有了一个应用，按照下面的描述将模板建立到一个新的文件夹中，作为对现有应用进行docker化的参考点--你可以将模板中的关键资源复制到你的应用中，并对它们稍作调整作为一个跳板。

1. 安装或构建Vapor工具箱（[macOS](.../install/macos.md#install-toolbox)，[Linux](.../install/linux.md#install-toolbox)）。
2. 用`vapor new my-dockerized-app`创建一个新的Vapor应用程序，并通过提示来启用或禁用相关功能。你对这些提示的回答将影响Docker资源文件的生成方式。

## Docker资源

无论是现在还是在不久的将来，熟悉一下[Docker概述](https://docs.docker.com/engine/docker-overview/)是值得的。该概述将解释本指南所使用的一些关键术语。

模板Vapor App有两个关键的Docker专用资源。一个**Dockerfile**和一个**docker-compose**文件。

### Dockerfile

Dockerfile告诉Docker如何为你的docker化应用建立一个镜像。该镜像包含你的应用的可执行文件和运行该应用所需的所有依赖项。当你致力于定制你的Dockerfile时，[完整参考](https://docs.docker.com/engine/reference/builder/)值得保持开放。

为你的Vapor应用程序生成的Dockerfile有两个阶段。第一阶段构建你的应用程序，并设置一个包含结果的保持区。第二阶段设置安全运行环境的基本要素，将保持区中的所有内容转移到最终镜像中，并设置一个默认的入口和命令，在默认端口（8080）上以生产模式运行你的应用程序。这个配置可以在使用镜像时被重写。

### Docker Compose文件

Docker Compose文件定义了Docker建立多个服务的方式，使其相互关联。Vapor应用程序模板中的Docker Compose文件提供了部署应用程序的必要功能，但如果你想了解更多，你应该查阅[完整参考](https://docs.docker.com/compose/compose-file/)，其中有关于所有可用选项的细节。

!!!注意
    如果你最终打算使用Kubernetes来协调你的应用，那么Docker Compose文件就不直接相关。然而，Kubernetes清单文件在概念上是相似的，甚至有一些项目旨在将[移植Docker Compose文件](https://kubernetes.io/docs/tasks/configure-pod-container/translate-compose-kubernetes/)移植到Kubernetes清单中。

新的Vapor App中的Docker Compose文件将定义运行App的服务，运行迁移或恢复迁移，以及运行数据库作为App的持久层。确切的定义将取决于你在运行`vapor new`时选择使用的数据库。

注意你的Docker Compose文件在顶部附近有一些共享的环境变量（你可能有一组不同的默认变量，这取决于你是否使用Fluent，以及如果你使用Fluent驱动。）

```docker
x-shared_environment: &shared_environment
  LOG_LEVEL: ${LOG_LEVEL:-debug}
  DATABASE_HOST: db
  DATABASE_NAME: vapor_database
  DATABASE_USERNAME: vapor_username
  DATABASE_PASSWORD: vapor_password
```

你会看到这些被拉到下面的多个服务中，有`<<: *shared_environment`YAML参考语法。

`DATABASE_HOST`, `DATABASE_NAME`, `DATABASE_USERNAME`, 和`DATABASE_PASSWORD`变量在这个例子中是硬编码的，而`LOG_LEVEL`将从运行服务的环境中取值，如果该变量未被设置，则返回到`'debug'`。

!!! note
    对于本地开发来说，硬编码的用户名和密码是可以接受的，但对于生产部署来说，你应该将这些变量存储在一个秘密文件中。在生产中处理这个问题的一个方法是将秘密文件导出到运行你的部署的环境中，并在你的Docker Compose文件中使用类似下面的行：

    ```
    DATABASE_USERNAME: ${DATABASE_USERNAME}
    ```

    这将把环境变量传递给主机定义的容器。

其他需要注意的事项。

- 服务的依赖性是由`depends_on`数组定义的。
- 服务端口通过`ports`数组暴露给运行服务的系统（格式为`<host_port>:<service_port>`）。
- `DATABASE_HOST`被定义为`db`。这意味着你的应用程序将在`http://db:5432`访问数据库。这是因为Docker将建立一个服务使用的网络，该网络的内部DNS将把`db`这个名字路由到名为`'db'`的服务。
- Docker文件中的`CMD`指令在一些服务中被`command`阵列覆盖。请注意，由`command`指定的内容是针对Dockerfile中的`ENTRYPOINT`运行的。
- 在Swarm模式下（下面会有更多介绍），服务默认为1个实例，但`migrate`和`revert`服务被定义为`deploy` `replicas: 0`，所以它们在运行Swarm时默认不会启动。

## 构建

Docker Compose文件告诉Docker如何构建你的应用程序（通过使用当前目录下的Dockerfile），以及如何命名生成的镜像（`my-dockerized-app:newth`）。后者实际上是一个名字（`my-dockerized-app`）和一个标签（`latest`）的组合，标签用于Docker镜像的版本。

要为你的应用程序建立一个Docker镜像，请运行
```shell
docker compose build
```
从你的应用程序项目的根目录（包含`docker-compose.yml`的文件夹）。

你会看到你的应用程序和它的依赖项必须重新构建，即使你之前在你的开发机器上构建过它们。它们是在Docker使用的Linux构建环境中构建的，所以来自你的开发机器的构建工件是不可重复使用的。

当它完成后，你会发现你的应用程序的图像，当运行
```shell
docker image ls
```

## 运行

你的服务栈可以直接从Docker Compose文件中运行，也可以使用Swarm模式或Kubernetes等协调层。

### 独立运行

运行你的应用程序的最简单方法是将其作为一个独立的容器启动。Docker将使用`depends_on`数组来确保任何依赖的服务也被启动。

首先，执行：
```shell
docker compose up app
```
并注意到`app`和`db`服务都已启动。

你的应用程序正在监听8080端口，正如Docker Compose文件所定义的，它可以在你的开发机器上访问**http://localhost:8080**。

这个端口映射的区别是非常重要的，因为你可以在相同的端口上运行任何数量的服务，如果它们都在自己的容器中运行，并且它们各自向主机暴露不同的端口。

访问`http://localhost:8080`，你会看到`It works!`但访问`http://localhost:8080/todos`，你会得到：
```
{"error":true,"reason":"Something went wrong."}
```

看一下你运行`docker compose up app`的终端的日志输出，你会看到：
```
[ ERROR ] relation "todos" does not exist
```

当然了! 我们需要在数据库上运行迁移程序。按`Ctrl+C`关闭你的应用程序。我们将再次启动该应用程序，但这次是用：
```shell
docker compose up --detach app
```

现在你的应用程序将"datached"启动（在后台）。你可以通过运行来验证这一点：
```shell
docker container ls
```
在那里你会看到数据库和你的应用程序都在容器中运行。你甚至可以通过运行来检查日志：
```shell
docker logs <container_id>
```

要运行迁移，请执行：
```shell
docker compose run migrate
```

迁移运行后，你可以再次访问`http://localhost:8080/todos`，你会得到一个空的todos列表，而不是错误信息。

#### Log Levels

回顾上文，Docker Compose文件中的`LOG_LEVEL`环境变量将从服务启动的环境中继承（如果有）。

你可以把你的服务用
```shell
LOG_LEVEL=trace docker-compose up app
```
来获得`trace`级别的日志（最细的）。你可以使用这个环境变量将日志设置为[任何可用级别](.../logging.md#levels)。

#### 所有服务日志

如果你在启动容器时明确指定了你的数据库服务，那么你会看到数据库和应用程序的日志。
```shell
docker-compose up app db
```

#### 使独立的容器停止运行

现在你已经让容器从你的主机外壳上"detached"运行，你需要告诉它们以某种方式关闭。值得注意的是，任何正在运行的容器都可以通过以下方式被要求关闭
```shell
docker container stop <container_id>
```
但要把这些特定的容器降下来，最简单的方法是
```shell
docker-compose down
```

#### 擦拭数据库

Docker Compose文件定义了一个`db_data`卷，用于在运行期间保持你的数据库。有几种方法可以重置你的数据库。

你可以在关闭容器的同时删除`db_data`卷，并使用
```shell
docker-compose down --volumes
```

你可以用`docker volume ls`查看任何当前持久化数据的卷。请注意，卷的名称通常会有一个`my-dockerized-app_`或`test_`的前缀，取决于你是否在Swarm模式下运行。

你可以一次删除这些卷，比如说
```shell
docker volume rm my-dockerized-app_db_data
```

你也可以用以下方法清理所有卷
```shell
docker volume prune
```

只是要注意不要不小心修剪了你想保留的有数据的卷!

Docker不会让你删除正在运行或停止的容器所使用的卷。你可以用`docker container ls`获得正在运行的容器的列表，你也可以用`docker container ls -a`看到停止的容器。

### Swarm模式

Swarm模式是一个简单的界面，当你有一个Docker Compose文件在手，并且你想测试你的应用程序如何横向扩展时，可以使用它。你可以在扎根于[概述](https://docs.docker.com/engine/swarm/)的页面中阅读关于Swarm模式的所有内容。

我们需要的第一件事是为我们的Swarm提供一个管理节点。运行
```shell
docker swarm init
```

接下来我们将使用我们的Docker Compose文件来建立一个名为`'test'`的堆栈，其中包含我们的服务
```shell
docker stack deploy -c docker-compose.yml test
```

我们可以通过以下方式了解我们的服务情况
```shell
docker service ls
```

你应该看到`app`和`db`服务有`1/1`个副本，`migrate`和`revert`服务有`0/0`个副本。

我们需要使用一个不同的命令来运行Swarm模式下的迁移。
```shell
docker service scale --detach test_migrate=1
```

!!! note
    我们刚刚要求一个短命的服务扩展到1个副本。它将成功扩大规模，运行，然后退出。然而，这将使它的`0/1`个复制在运行。在我们想再次运行迁移之前，这没什么大不了的，但是如果它已经处于这个状态，我们就不能告诉它"扩展到1个副本"。这种设置的一个怪癖是，当我们下次想在同一个Swarm运行时间内运行迁移时，我们需要首先将服务缩减到`0`，然后再回升到`1`。

在这个简短的指南中，我们的麻烦的回报是，现在我们可以将我们的应用程序扩展到任何我们想要的程度，以测试它对数据库争用、崩溃等的处理情况。

如果你想同时运行5个应用程序的实例，执行
```shell
docker service scale test_app=5
```

除了观察docker扩展你的应用程序，你还可以通过再次检查`docker service ls`看到5个副本确实在运行。

你可以通过以下方式查看（和跟踪）你的应用程序的日志
```shell
docker service logs -f test_app
```

#### 将Swarm服务关闭

当你想在Swarm模式下关闭你的服务时，你可以通过移除你先前创建的堆栈来实现。
```shell
docker stack rm test
```

## 生产部署

如上所述，本指南不会详细介绍将docker化应用部署到生产环境中的问题，因为这个话题很大，而且根据托管服务（AWS、Azure等）、工具（Terraform、Ansible等）和协调（Docker Swarm、Kubernetes等）的不同而变化很大。

然而，你所学习的在开发机器上本地运行docker化应用的技术在很大程度上可以转移到生产环境。为运行docker守护程序而设置的服务器实例将接受所有相同的命令。

将你的项目文件复制到服务器上，通过SSH进入服务器，并运行`docker-compose`或`docker stack deploy`命令来实现远程运行。

或者，设置你的本地`DOCKER_HOST`环境变量指向你的服务器，在你的机器上运行`docker`命令。值得注意的是，使用这种方法，你不需要将任何项目文件复制到服务器上，但你需要将你的docker镜像寄存在服务器可以提取的地方。
