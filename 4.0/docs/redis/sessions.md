# Redis与会话

Redis可以作为一个存储提供者来缓存[会话数据](.../sessions.md#session-data)，如用户证书。

如果没有提供自定义的[`RedisSessionsDelegate`](https://api.vapor.codes/redis/master/Redis/RedisSessionsDelegate/)，将使用默认值。

## 默认行为

### SessionID创建

除非你在[你自己的`RedisSessionsDelegate`](#RedisSessionsDelegate)中实现[`makeNewID()`](https://api.vapor.codes/redis/master/Redis/RedisSessionsDelegate/#redissessionsdelegate.makeNewID())方法，否则所有[`SessionID`](https://api.vapor.codes/vapor/master/Vapor/SessionID/)值都将通过以下方式创建：

1. 生成32字节的随机字符
1. 对该值进行base64编码

例如：`Hbxozx8rTj+XXGWAzOhh1npZFXaGLpTWpWCaXuo44xQ=`。

### 会话数据存储

`RedisSessionsDelegate`的默认实现将使用`Codable`将[`SessionData`](https://api.vapor.codes/vapor/master/Vapor/SessionData/)存储为一个简单的JSON字符串值。

除非你在自己的`RedisSessionsDelegate`中实现了[`makeRedisKey(for:)`](https://api.vapor.codes/redis/master/Redis/RedisSessionsDelegate/#redissessionsdelegate.makeRedisKey(for:))方法，否则`SessionData`将以`vrs-`（**V**apor **R**edis **S**essions）为前缀的钥匙存储在Redis中。

例如：`vrs-Hbxozx8rTj+XXGWAzOhh1npZFXaGLpTWpWCaXuo44xQ=`

## 注册一个自定义代理

要定制数据从Redis读取和写入Redis的方式，请注册你自己的`RedisSessionsDelegate`对象，如下所示：

```swift
import Redis

struct CustomRedisSessionsDelegate: RedisSessionsDelegate {
    // 执行
}

app.sessions.use(.redis(delegate: CustomRedisSessionsDelegate()))
```

## RedisSessionsDelegate

> API文档：[`RedisSessionsDelegate`](https://api.vapor.codes/redis/master/Redis/RedisSessionsDelegate/)

符合该协议的对象可以用来改变Redis中`SessionData`的存储方式。

符合该协议的类型只需要实现两个方法。[`redis(_:store:with:)`](https://api.vapor.codes/redis/master/Redis/RedisSessionsDelegate/#redissessionsdelegate.redis(_:store:with:))和[`redis(_:fetchDataFor:)`](https://api.vapor.codes/redis/master/Redis/RedisSessionsDelegate/#redissessionsdelegate.redis(_:fetchDataFor:) )。

这两个都是必须的，因为你自定义将会话数据写入Redis的方式与如何从Redis读取数据有内在联系。

### RedisSessionsDelegate Hash 示例

例如，如果你想把会话数据存储为[**Hash**在Redis中](https://redis.io/topics/data-types-intro#redis-hashes)，你可以实现如下内容。

```swift
func redis<Client: RedisClient>(
    _ client: Client,
    store data: SessionData,
    with key: RedisKey
) -> EventLoopFuture<Void> {
    // 将每个数据字段存储为一个单独的哈希字段
    return client.hmset(data.snapshot, in: key)
}
func redis<Client: RedisClient>(
    _ client: Client,
    fetchDataFor key: RedisKey
) -> EventLoopFuture<SessionData?> {
    return client
        .hgetall(from: key)
        .map { hash in
            // 哈希值是[String: RESPValue]，所以我们需要尝试将其解包为字符串，并将每个值存储在数据容器中。
            // 变成一个字符串，并将每个值存储在数据容器中。
            return hash.reduce(into: SessionData()) { result, next in
                guard let value = next.value.string else { return }
                result[next.key] = value
            }
        }
}
```
