# 会话

会话允许你在多个请求之间持续保存用户的数据。会话的工作方式是，当一个新的会话被初始化时，在HTTP响应旁边创建并返回一个独特的cookie。浏览器会自动检测这个cookie，并将其包含在未来的请求中。这允许Vapor在你的请求处理程序中自动恢复一个特定用户的会话。

会话对于在Vapor中构建的直接向Web浏览器提供HTML的前端Web应用是非常好的。对于API，我们建议使用无状态的，[基于令牌的认证](../security/authentication.md)来保持用户数据在两次请求之间。

## 配置

要在路由中使用会话，请求必须通过`SessionsMiddleware`。最简单的方法是在全局范围内添加这个中间件来实现这一点。

```swift
app.middleware.use(app.sessions.middleware)
```

如果你的路由中只有一部分利用会话，你可以把`SessionsMiddleware`添加到路由组。

```swift
let sessions = app.grouped(app.sessions.middleware)
```

由会话生成的HTTP cookie可以使用`app.session.configuration`来配置。你可以改变cookie的名称，并声明一个用于生成cookie值的自定义函数。

```swift
// 将cookie的名称改为 "foo"。
app.sessions.configuration.cookieName = "foo"

// 配置cookie的价值创造。
app.sessions.configuration.cookieFactory = { sessionID in
    .init(string: sessionID.string, isSecure: true)
}
```

默认情况下，Vapor将使用`vapor_session`作为cookie名称。

## 驱动程序

会话驱动程序负责按标识符存储和检索会话数据。你可以通过符合`SessionDriver`协议来创建自定义的驱动程序。

!!! warning
    会话驱动应该在添加`app.session.middleware`到你的应用程序之前配置好。

### 内存中

Vapor默认使用内存中的会话。内存会话不需要任何配置，也不会在应用程序启动时持续存在，这使得它们非常适用于测试。要手动启用内存会话，请使用`.memory`。

```swift
app.sessions.use(.memory)
```

对于生产用例，可以看看其他的会话驱动，它们利用数据库在你的应用程序的多个实例中坚持和共享会话。

### Fluent

Fluent包括支持将会话数据存储在你的应用程序的数据库中。本节假设你已经[配置了Fluent](../fluent/overview.md)并能连接到数据库。第一步是启用Fluent会话驱动。

```swift
import Fluent

app.sessions.use(.fluent)
```

这将把会话配置为使用应用程序的默认数据库。要指定一个特定的数据库，请传递数据库的标识符。

```swift
app.sessions.use(.fluent(.sqlite))
```

最后，将`SessionRecord`的迁移添加到你的数据库的迁移中。这将为你的数据库在`_fluent_sessions`模式中存储会话数据做好准备。

```swift
app.migrations.add(SessionRecord.migration)
```

请确保在添加新的迁移后运行你的应用程序的迁移。现在，会话将被存储在你的应用程序的数据库中，允许它们在重新启动时持续存在，并在你的应用程序的多个实例之间共享。

### Redis

Redis提供了对在你配置的Redis实例中存储会话数据的支持。本节假设你已经[配置了Redis](../redis/overview.md)，并且可以向Redis实例发送命令。

要将 Redis 用于会话，请在配置你的应用程序时选择它。

```swift
import Redis

app.sessions.use(.redis)
```

这将配置会话以使用Redis会话驱动程序的默认行为。

!!! Seealso
    参考 [Redis &rarr; Sessions](../redis/sessions.md) 以了解有关 Redis 和 Sessions 的更多详细信息。

## 会话数据

现在会话已经配置好了，你已经准备好在请求之间持续保存数据。当数据被添加到`req.session`中时，新的会话会自动被初始化。下面的示例路由处理程序接受一个动态路由参数，并将其值添加到`req.session.data`。

```swift
app.get("set", ":value") { req -> HTTPStatus in
    req.session.data["name"] = req.parameters.get("value")
    return .ok
}
```

使用下面的请求来初始化一个名为Vapor的会话。

```http
GET /set/vapor HTTP/1.1
content-length: 0
```

你应该收到类似于以下的答复：

```http
HTTP/1.1 200 OK
content-length: 0
set-cookie: vapor-session=123; Expires=Fri, 10 Apr 2020 21:08:09 GMT; Path=/
```

注意在向`req.session`添加数据后，`set-cookie`头被自动添加到响应中。在随后的请求中包括这个cookie将允许对会话数据的访问。

添加以下路由处理程序，用于访问会话中的名称值。

```swift
app.get("get") { req -> String in
    req.session.data["name"] ?? "n/a"
}
```

使用下面的请求来访问这个路由，同时确保传递先前响应中的cookie值。

```http
GET /get HTTP/1.1
cookie: vapor-session=123
```

你应该看到响应中返回的名称是Vapor。你可以在你认为合适的时候添加或删除会话中的数据。会话数据将在返回HTTP响应前自动与会话驱动程序同步。

要结束一个会话，使用`req.session.destroy`。这将从会话驱动中删除数据并使会话cookie无效。

```swift
app.get("del") { req -> HTTPStatus in
    req.session.destroy()
    return .ok
}
```
