# Logging 

Vapor的 `Logging` API 是构建在 [SwiftLog](https://github.com/apple/swift-log) 之上。 这意味着 Vapor 兼容所有基于 `SwiftLog` 的[后端实现](https://github.com/apple/swift-log#backends)。

~~Vapor's logging API is built on top of [SwiftLog](https://github.com/apple/swift-log). This means Vapor is compatible with all of SwiftLog's [backend implementations](https://github.com/apple/swift-log#backends).~~

## Logger

`Logger` 的实例用于输出日志消息。Vapor 提供一些简单的方法使用日志记录器。

~~Instances of `Logger` are used for outputting log messages. Vapor provides a few easy ways to get access to a logger.~~

### Request

每个传入 `Request` 都有一个单独的日志记录器，你可以在该请求中使用任何类型日志。

~~Each incoming `Request` has a unique logger that you should use for any logs specific to that request.~~

```swift
app.get("hello") { req -> String in
    req.logger.info("Hello, logs!")
    return "Hello, world!"
}
```

请求的日志记录器都有一个单独的`UUID`用于标识该请求，方便跟踪该日志。

~~The request logger includes a unique UUID identifying the incoming request to make tracking logs easier.~~

```
[ INFO ] Hello, logs! [request-id: C637065A-8CB0-4502-91DC-9B8615C5D315] (App/routes.swift:10)
```

!!! info
	~~Logger metadata will only be shown in debug log level or lower.~~
    日志记录器的元数据仅在调试日志级别或者更低级别显示。

### ~~Application~~
### 应用

关于应用程序启动和配置过程中的日志消息，可以使用 `Application` 的日志记录器。
~~For log messages during app boot and configuration, use `Application`'s logger.~~

```swift
app.logger.info("Setting up migrations...")
app.migrations.use(...)
```

### ~~Custom Logger~~
### 自定义日志记录器

在你无法使用 `Application` 或者 `Request` 情况下，你可以初始化一个新的 `Logger`。

~~In situations where you don't have access to `Application` or `Request`, you can initialize a new `Logger`.~~

```swift
let logger = Logger(label: "dev.logger.my")
logger.info(...)
```
虽然自定义的日志记录器仍将输出你配置的后端日志记录，但是他们没有附加重要的元数据，比如`request`的`UUID`。所以尽量使用 `application` 或者 `request` 的日志记录器。

~~While custom loggers will still output to your configured logging backend, they will not have important metadata attached like request UUID. Use the request or application specific loggers wherever possible.~~ 

## ~~Level~~
## 日志级别

~~SwiftLog supports several different logging levels.~~
`SwiftLog` 支持多个不同的日志级别。

|名称|说明|
|-|-|
|trace|用户级基本输出~~Appropriate for messages that contain information only when debugging a program.~~|
|debug|用户级调试~~Appropriate for messages that contain information normally of use only when debugging a program.~~|
|info|用户级重要~~Appropriate for informational messages.~~|
|notice|表明会出现非错误的情形，需要关注处理~~Appropriate for conditions that are not error conditions, but that may require special handling.~|
|warning|表明会出现潜在错误的情形，比 `notice` 的消息 严重~~Appropriate for messages that are not error conditions, but more severe than notice.~~|
|error|指出发生错误事件，但仍然不影响系统的继续运行~~Appropriate for error conditions.~~|
|critical|系统级危险，需要关注错误情况~~Appropriate for critical error conditions that usually require immediate attention.~~|

出现 `critical` 消息时，日志框架可以自由的执行权限更重的操作来捕获系统状态（比如捕获跟踪堆栈）以方便调试。
~~When a `critical` message is logged, the logging backend is free to perform more heavy-weight operations to capture system state (such as capturing stack traces) to facilitate debugging.~~

默认情况下，Vapor 使用 `info` 级别日志。当运行在 `production` 环境时，将使用 `notice` 提高性能。
~~By default, Vapor will use `info` level logging. When run with the `production` environment, `notice` will be used to improve performance.~~

### ~~Changing Log Level~~
### 修改日志级别

不管环境模式如何，你都可以通过修改日志级别来增加或减少生成的日志数量
~~Regardless of environment mode, you can override the logging level to increase or decrease the amount of logs produced.~~

第一种方法,启动应用程序是传递可选参数 `--log` 标志
~~The first method is to pass the optional `--log` flag when booting your application.~~

```sh
vapor run serve --log debug
```

第二种方法，通过设置 `LOG_LEVEL` 环境变量
~~The second method is to set the `LOG_LEVEL` environment variable.~~

```sh
export LOG_LEVEL=debug
vapor run serve
```
这两种方法可以通过 Xcode 中编辑 `Run` 模式进行修改。
~~Both of these can be done in Xcode by editing the `Run` scheme.~~

## ~~Configuration~~
## 配置

`SwiftLog` 可以通过每次进程启动 `LoggingSystem` 时进行配置。 Vapor 项目通常在 `main.swift` 执行操作。
~~SwiftLog is configured by boostrapping the `LoggingSystem` once per process. Vapor projects typically do this in `main.swift`.~~

```swift
import Vapor

var env = try Environment.detect()
try LoggingSystem.bootstrap(from: &env)
```

`bootstrap(from:)` 是 Vapor 提供的调用方法，它将基于命令行参数和环境变量来配置默认日志处理操作。默认的日志处理操作支持使用ANSI颜色支持将消息输出到终端。

~~`bootstrap(from:)` is a helper method provided by Vapor that will configure the default log handler based on command-line arguments and environment variables. The default log handler supports outputting messages to the terminal with ANSI color support.~~ 

### ~~Custom Handler~~
### 自定义操作

你可以覆盖 Vapor 的默认日志处理操作并注册自己的日志处理操作。
~~You can override Vapor's default log handler and register your own.~~

```swift
import Logging

LoggingSystem.bootstrap { label in
    StreamLogHandler.standardOutput(label: label)
}
```

所有 SwiftLog 支持的后端框架均可与 Vapor 一起工作。但是，使用命令行参数和环境变量更改日志级别只支持 Vapor 的默认日志处理操作。
~~All of SwiftLog's supported backends will work with Vapor. However, changing the log level with command-line arguments and environment variables is only compatible with Vapor's default log handler.~~
