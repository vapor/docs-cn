# 队列

Vapor Queues（[vapor/queues](https://github.com/vapor/queues)）是一个纯粹的Swift队列系统，允许你将任务责任卸载给一个侧翼工作者。

这个package的一些任务很好用：

- 在主请求线程之外发送电子邮件
- 执行复杂或长时间运行的数据库操作 
- 确保工作的完整性和复原力 
- 通过延迟非关键性的处理来加快响应时间
- 将工作安排在特定的时间发生

这个包类似于[Ruby Sidekiq](https://github.com/mperham/sidekiq)。它提供了以下功能：

- 安全地处理主机供应商发送的`SIGTERM`和`SIGINT`信号，以表示关闭、重新启动或新的部署。
- 不同的队列优先级。例如，你可以指定一个队列作业在电子邮件队列中运行，另一个作业在数据处理队列中运行。
- 实施可靠的队列进程，以帮助处理意外故障。
- 包括一个`maxRetryCount`功能，它将重复作业，直到它成功到指定的计数。
- 使用NIO来利用所有可用的核心和作业的EventLoops。
- 允许用户安排重复的任务

Queues目前有一个官方支持的驱动程序，它与主协议接口：

- [QueuesRedisDriver](https://github.com/vapor/queues-redis-driver)

Queues也有基于社区的驱动程序。
- [QueuesMongoDriver](https://github.com/vapor-community/queues-mongo-driver)
- [QueuesFluentDriver](https://github.com/m-barthelemy/vapor-queues-fluent-driver)

!!! Tip
    你不应该直接安装`vapor/queues`包，除非你正在构建一个新的驱动程序。应该安装其中的一个驱动包。

## 开始使用

让我们来看看你如何开始使用队列。

### Package

使用 Queues 的第一步是在 SwiftPM 包清单文件中将其中一个驱动程序作为依赖项添加到您的项目中。在本例中，我们将使用 Redis 驱动程序。

```swift
// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "MyApp",
    dependencies: [
        /// 任何其他的依赖性...
        .package(url: "https://github.com/vapor/queues-redis-driver.git", from: "1.0.0"),
    ],
    targets: [
        .target(name: "App", dependencies: [
            .product(name: "QueuesRedisDriver", package: "queues-redis-driver")
        ]),
        .target(name: "Run", dependencies: [.target(name: "App")]),
        .testTarget(name: "AppTests", dependencies: [.target(name: "App")]),
    ]
)
```

如果您在Xcode中直接编辑清单，它将会自动接收更改并在保存文件时获取新的依赖关系。否则，从终端运行`swift package resolve`来获取新的依赖关系。

### 配置

下一步是在`configure.swift`中配置队列。我们将使用Redis库作为一个例子：

```swift
try app.queues.use(.redis(url: "redis://127.0.0.1:6379"))
```

### 注册一个Job

在建立一个作业模型后，你必须把它添加到你的配置部分，像这样：

```swift
// 注册工作
let emailJob = EmailJob()
app.queues.add(emailJob)
```

### 以进程形式运行Workers

要启动一个新的队列Worker，运行`vapor run queues`。你也可以指定一个特定类型的Worker来运行：`vapor run queues --queue emails`。

!!! Tip
    Workers应在生产中保持运行。请咨询您的主机提供商，了解如何保持长期运行的进程。例如，Heroku允许你在Procfile中这样指定 "worker"动态。`worker: Run queues`。有了这个，你可以在Dashboard/Resources标签上启动worker，或者用`heroku ps:scale worker=1`（或任何数量的dynos优先）。

### 在进程中运行Workers

要在与你的应用程序相同的进程中运行一个worker（而不是启动一个单独的服务器来处理它），请调用`Application`上的便利方法：

```swift
try app.queues.startInProcessJobs(on: .default)
```

要在进程中运行预定的工作，请调用以下方法：

```swift
try app.queues.startScheduledJobs()
```

!!! warning
    如果你不通过命令行或进程中的工作者启动队列工作者，作业就不会被派发。

## `Job`协议

工作是由`Job`或`AsyncJob`协议定义的。

### 建立一个`Job`对象的模型：

```swift
import Vapor 
import Foundation 
import Queues 

struct Email: Codable {
    let to: String
    let message: String
}

struct EmailJob: Job {
    typealias Payload = Email
    
    func dequeue(_ context: QueueContext, _ payload: Email) -> EventLoopFuture<Void> {
        // 这是你要发送电子邮件的地方
        return context.eventLoop.future()
    }
    
    func error(_ context: QueueContext, _ error: Error, _ payload: Email) -> EventLoopFuture<Void> {
        // 如果你不想处理错误，你可以简单地返回一个未来。你也可以完全省略这个函数。
        return context.eventLoop.future()
    }
}
```

如果使用`async`/`await`，你应该使用`AsyncJob`：

```swift
struct EmailJob: AsyncJob {
    typealias Payload = Email
    
    func dequeue(_ context: QueueContext, _ payload: Email) async throws {
        // 这是你要发送电子邮件的地方
    }
    
    func error(_ context: QueueContext, _ error: Error, _ payload: Email) async throws {
        // 如果你不想处理错误，你可以直接返回。你也可以完全省略这个函数。
    }
}
```

!!! Tip
    不要忘了按照**入门**中的说明，将这项工作添加到你的配置文件中。

## 调度Jobs

要调度一个队列作业，你需要访问`Application`或`Request`的一个实例。你很可能会在路由处理程序中调度作业。

```swift
app.get("email") { req -> EventLoopFuture<String> in
    return req
        .queue
        .dispatch(
            EmailJob.self, 
            .init(to: "email@email.com", message: "message")
        ).map { "done" }
}

// 或

app.get("email") { req async throws -> String in
    try await req.queue.dispatch(
        EmailJob.self, 
        .init(to: "email@email.com", message: "message"))
    return "done"
}
```

### 设置`maxRetryCount`。

如果你指定了一个`maxRetryCoun`，作业会在出错时自动重试。例如: 

```swift
app.get("email") { req -> EventLoopFuture<String> in
    return req
        .queue
        .dispatch(
            EmailJob.self, 
            .init(to: "email@email.com", message: "message"),
            maxRetryCount: 3
        ).map { "done" }
}

// 或

app.get("email") { req async throws -> String in
    try await req.queue.dispatch(
        EmailJob.self, 
        .init(to: "email@email.com", message: "message"),
        maxRetryCount: 3)
    return "done"
}
```

### 指定一个延迟

工作也可以被设置为只在某个`Date`过后运行。要指定一个延迟，在`dispatch`的`delayUntil`参数中传递一个`Date`：

```swift
app.get("email") { req async throws -> String in
    let futureDate = Date(timeIntervalSinceNow: 60 * 60 * 24) // One day
    try await req.queue.dispatch(
        EmailJob.self, 
        .init(to: "email@email.com", message: "message"),
        maxRetryCount: 3,
        delayUntil: futureDate)
    return "done"
}
```

如果一个作业在其延迟参数之前被取消排队，该作业将被驱动重新排队。

### 指定一个优先级 

作业可以根据你的需要被分到不同的队列类型/优先级。例如，你可能想开一个`email`队列和一个`background-processing`队列来分类作业。

通过扩展`QueueName`开始。

```swift
extension QueueName {
    static let emails = QueueName(string: "emails")
}
```

然后，在检索`jobs`对象时指定队列类型：

```swift
app.get("email") { req -> EventLoopFuture<String> in
    let futureDate = Date(timeIntervalSinceNow: 60 * 60 * 24) // One day
    return req
        .queues(.emails)
        .dispatch(
            EmailJob.self, 
            .init(to: "email@email.com", message: "message"),
            maxRetryCount: 3,
            delayUntil: futureDate
        ).map { "done" }
}

// 或

app.get("email") { req async throws -> String in
    let futureDate = Date(timeIntervalSinceNow: 60 * 60 * 24) // One day
    try await req
        .queues(.emails)
        .dispatch(
            EmailJob.self, 
            .init(to: "email@email.com", message: "message"),
            maxRetryCount: 3,
            delayUntil: futureDate
        )
    return "done"
}
```

如果你不指定队列，作业将在 "默认 "队列上运行。请确保按照**入门**中的说明，为每个队列类型启动工作者。

## 调度Jobs

队列包还允许你将作业安排在某些时间点上发生。

### 启动调度器的工作程序
调度器需要运行一个单独的工作进程，与队列工作器类似。你可以通过运行这个命令来启动这个工作程序。

```sh
swift run Run queues --scheduled
```

!!! Tip
    工人应该在生产中保持运行。请咨询你的主机提供商，了解如何让长期运行的进程保持活力。例如，Heroku允许你在Procfile中像这样指定"worker"动态：`worker: Run queues --scheduled`。

### 创建一个ScheduledJob

首先，创建一个新的`ScheduledJob`或`AsyncScheduledJob`：

```swift
import Vapor
import Queues

struct CleanupJob: ScheduledJob {
    // 如果你需要的话，在这里通过依赖性注入添加额外的服务。

    func run(context: QueueContext) -> EventLoopFuture<Void> {
        // 在这里做一些工作，或许可以排队做另一份工作。
        return context.eventLoop.makeSucceededFuture(())
    }
}

struct CleanupJob: AsyncScheduledJob {
    // 如果你需要的话，在这里通过依赖性注入添加额外的服务。

    func run(context: QueueContext) async throws {
        // 在这里做一些工作，或许可以排队做另一份工作。
    }
}
```

然后，在你的配置代码中，注册ScheduledJob：

```swift
app.queues.schedule(CleanupJob())
    .yearly()
    .in(.may)
    .on(23)
    .at(.noon)
```

上面例子中的工作将在每年的5月23日12:00点运行。

!!! Tip
    Scheduler采用你的服务器的时区。

### 可用的构建器方法
有五个主要的方法可以在调度器上调用，每个方法都会创建各自的构建器对象，其中包含更多的辅助方法。你应该继续构建一个调度器对象，直到编译器不给你一个关于未使用结果的警告。所有可用的方法见下文。

| 帮助函数 | 可用的修改器 | 描述 |
|-----------------|---------------------------------------|--------------------------------------------------------------------------------|
| `yearly()`      | `in(_ month: Month) -> Monthly`       | 运行该工作的月份。返回一个`Monthly`对象，以便进一步构建。  |
| `monthly()`     | `on(_ day: Day) -> Daily`             | 运行该工作的日期。返回一个`Daily`的对象，以便进一步构建。      |
| `weekly()`      | `on(_ weekday: Weekday) -> Daily` | 在一周中的哪一天运行工作。返回一个`Daily`对象。               |
| `daily()`       | `at(_ time: Time)`                    | 运行该作业的时间。链中的最后一个方法。                        |
|                 | `at(_ hour: Hour24, _ minute: Minute)`| 运行该作业的小时和分钟。链中的最后一个方法。              |
|                 | `at(_ hour: Hour12, _ minute: Minute, _ period: HourPeriod)` | 运行该工作的小时、分钟和时期。链的最终方法 |
| `hourly()`      | `at(_ minute: Minute)`                 | 运行该工作的分钟数。链的最终方法。                      |

### 可用的帮助器 
队列带有一些帮助器枚举，使调度更容易。

| 帮助函数 | 可用的帮助枚举 |
|-----------------|---------------------------------------|
| `yearly()`      | `.january`, `.february`, `.march`, ...|
| `monthly()`     | `.first`, `.last`, `.exact(1)`        |
| `weekly()`      | `.sunday`, `.monday`, `.tuesday`, ... |
| `daily()`       | `.midnight`, `.noon`                  |

要使用帮助器枚举，请在帮助器函数上调用相应的修改器并传递数值。例如：

```swift
// 每年的1月 
.yearly().in(.january)

// 每个月的第一天 
.monthly().on(.first)

// 每星期的星期天 
.weekly().on(.sunday)

// 每天午夜时分
.daily().at(.midnight)
```

## 事件代理 
Queues包允许你指定`JobEventDelegate`对象，当工作者对作业采取行动时，这些对象将收到通知。这可用于监控、浮现洞察力或警报目的。

要开始使用，请将一个对象与`JobEventDelegate`相符合，并实现任何所需的方法

```swift
struct MyEventDelegate: JobEventDelegate {
    /// 当作业从一个路由被分派到队列工作者时被调用
    func dispatched(job: JobEventData, eventLoop: EventLoop) -> EventLoopFuture<Void> {
        eventLoop.future()
    }

    /// 当作业被放入处理队列并开始工作时被调用
    func didDequeue(jobId: String, eventLoop: EventLoop) -> EventLoopFuture<Void> {
        eventLoop.future()
    }

    /// 当作业完成处理并从队列中移除时被调用。
    func success(jobId: String, eventLoop: EventLoop) -> EventLoopFuture<Void> {
        eventLoop.future()
    }

    /// 当作业完成处理但有错误时被调用。
    func error(jobId: String, error: Error, eventLoop: EventLoop) -> EventLoopFuture<Void> {
        eventLoop.future()
    }
}
```

然后，在你的配置文件中添加它：

```swift
app.queues.add(MyEventDelegate())
```

有许多第三方软件包使用委托功能来提供对你的队列工作者的额外洞察力：

- [QueuesDatabaseHooks](https://github.com/vapor-community/queues-database-hooks)
- [QueuesDash](https://github.com/gotranseo/queues-dash)
