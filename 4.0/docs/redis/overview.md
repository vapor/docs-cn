# Redis

[Redis](https://redis.io/)是最流行的内存数据结构存储之一，通常作为缓存或消息代理使用。

这个库是Vapor和[**RediStack**](https://gitlab.com/mordil/redistack)的集成，后者是与Redis通信的底层驱动。

!!!注意
    Redis的大部分功能是由**RediStack**提供的。
    我们强烈建议熟悉它的文档。
    
    在适当的地方提供了链接。

## Package

使用Redis的第一步是在你的Swift包清单中把它作为一个依赖项加入你的项目。

> 这个例子是针对一个现有的包。关于启动新项目的帮助，请参见[入门](.../hello-world.md)主指南。

```swift
dependencies: [
    // ...
    .package(url: "https://github.com/vapor/redis.git", from: "4.0.0")
]
// ...
targets: [
    .target(name: "App", dependencies: [
        // ...
        .product(name: "Redis", package: "redis")
    ])
]
```

## 配置

Vapor对[`RedisConnection`](https://docs.redistack.info/Classes/RedisConnection.html)实例采用了池化策略，有几个选项可以配置单个连接和池子本身。

配置Redis的最低要求是提供一个连接的URL：

```swift
let app = Application()

app.redis.configuration = try RedisConfiguration(hostname: "localhost")
```

### Redis配置

> API文档。[`RedisConfiguration`](https://api.vapor.codes/redis/main/Redis/RedisConfiguration/)

#### serverAddresses

如果你有多个Redis端点，比如一个Redis实例集群，你会想创建一个[`[SocketAddress]`](https://apple.github.io/swift-nio/docs/current/NIOCore/Enums/SocketAddress.html#/s:3NIO13SocketAddressO04makeC13ResolvingHost_4portACSS_SitKFZ)集合来代替传递初始化器。

创建`SocketAddress`的最常见方法是使用[`makeAddressResolvingHost(_:port:)`](https://apple.github.io/swift-nio/docs/current/NIOCore/Enums/SocketAddress.html#/s:3NIO13SocketAddressO04makeC13ResolvingHost_4portACSS_SitKFZ)静态方法。

```swift
let serverAddresses: [SocketAddress] = [
  try .makeAddressResolvingHost("localhost", port: RedisConnection.Configuration.defaultPort)
]
```

对于一个单一的Redis端点，使用方便的初始化器可能更容易，因为它将为你处理创建`SocketAddress`。

- [`.init(url:pool)`](https://api.vapor.codes/redis/main/Redis/RedisConfiguration/#redisconfiguration.init(url:pool:)) (with `String` or [`Foundation.URL`](https://developer.apple.com/documentation/foundation/url))
- [`.init(hostname:port:password:database:pool:)`](https://api.vapor.codes/redis/main/Redis/RedisConfiguration/#redisconfiguration.init(hostname:port:password:database:pool:))

#### 密码

如果你的Redis实例是由密码保护的，你需要把它作为`password`参数传递。

每个连接在创建时，都将使用该密码进行验证。

#### 数据库

这是你希望在创建每个连接时选择的数据库索引。

这使你不必自己向Redis发送`SELECT`命令。

!!! warning
    数据库的选择不会被维护。自己发送`SELECT`命令时要小心。

### 连接池选项

> API文档：[`RedisConfiguration.PoolOptions`](https://api.vapor.codes/redis/main/Redis/RedisConfiguration_PoolOptions/)

!!! note
    这里只强调了最常改变的选项。对于所有的选项，请参考API文档。

#### minimumConnectionCount

这是设置你希望每个池子在任何时候都保持多少个连接的值。

如果你的值是`0`，那么如果连接因任何原因丢失，池将不会重新创建它们，直到需要。

这被称为"冷启动"连接，与维持最小连接数相比，确实有一些开销。

#### maximumConnectionCount

这个选项决定了如何维护最大连接数的行为。

!!! seealso
    参考[`RedisConnectionPoolSize`](https://docs.redistack.info/Enums/RedisConnectionPoolSize.html) API，熟悉有哪些选项。

## 发送命令

你可以使用任何[`Application`](https://api.vapor.codes/vapor/main/Vapor/Application/)或[`Request`](https://api.vapor.codes/vapor/main/Vapor/Request/)实例上的`.redis`属性来发送命令，这将使你能够访问一个[`RedisClient`](https://docs.redistack.info/Protocols/RedisClient.html)。

任何`RedisClient`都有几个扩展，用于所有各种[Redis命令](https://redis.io/commands)。

```swift
let value = try app.redis.get("my_key", as: String.self).wait()
print(value)
// Optional("my_value")

// or

let value = try await app.redis.get("my_key", as: String.self)
print(value)
// Optional("my_value")
```

### 不支持的命令

如果**RediStack**不支持带有扩展方法的命令，你仍然可以手动发送。

```swift
// 命令后面的每个值是Redis期望的位置参数
try app.redis.send(command: "PING", with: ["hello"])
    .map {
        print($0)
    }
    .wait()
// "hello"

// 或

let res = try await app.redis.send(command: "PING", with: ["hello"])
print(res)
// "hello"
```

## Pub/Sub模式

Redis支持进入["Pub/Sub "模式](https://redis.io/topics/pubsub)的能力，其中一个连接可以监听特定的"通道"，并在订阅的通道发布"消息"（一些数据值）时运行特定的关闭。

订阅有一个确定的生命周期。

1. **subscribe**：当订阅第一次开始时调用一次。
1. **message**：当消息被发布到订阅的频道时被调用0次以上。
1. **unsubscribe**：当订阅结束时调用一次，无论是请求还是连接丢失。

当你创建一个订阅时，你必须至少提供一个[`messageReceiver`](https://docs.redistack.info/Typealiases.html#/s:9RediStack32RedisSubscriptionMessageReceiver)来处理所有由订阅频道发布的消息。

你可以选择为`onSubscribe`和`onUnsubscribe`提供一个[`RedisSubscriptionChangeHandler`](https://docs.redistack.info/Typealiases.html#/s:9RediStack30RedisSubscriptionChangeHandlera)，以处理它们各自的生命周期事件。

```swift
// 创建2个订阅，每个给定通道一个
app.redis.subscribe
  to: "channel_1", "channel_2",
  messageReceiver: { channel, message in
    switch channel {
    case "channel_1": // do something with the message
    default: break
    }
  },
  onUnsubscribe: { channel, subscriptionCount in
    print("unsubscribed from \(channel)")
    print("subscriptions remaining: \(subscriptionCount)")
  }
```
