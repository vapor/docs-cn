# 密码

Vapor包括一个密码散列API，帮助你安全地存储和验证密码。该API可根据环境进行配置，并支持异步散列。

## 配置

要配置应用程序的密码散列器，请使用`app.passwords`。

```swift
import Vapor

app.passwords.use(...)
```

### Bcrypt

要使用Vapor的[Bcrypt API](crypto.md#bcrypt)进行密码散列，指定`.bcrypt`。这是默认的。

```swift
app.passwords.use(.bcrypt)
```

除非另有规定，否则Bcrypt将使用12的成本。你可以通过传递`cost`参数来配置。

```swift
app.passwords.use(.bcrypt(cost: 8))
```

### 明文

Vapor包括一个不安全的密码收集器，它以明文形式存储和验证密码。这不应该在生产中使用，但对测试是有用的。

```swift
switch app.environment {
case .testing:
    app.passwords.use(.plaintext)
default: break
}
```

## Hashing

要对密码进行散列，请使用`Request`上的`password`助手。

```swift
let digest = try req.password.hash("vapor")
```

密码摘要可以用`verify`方法与明文密码进行验证。

```swift
let bool = try req.password.verify("vapor", created: digest)
```

同样的API在`Application`上也可以使用，以便在启动时使用。

```swift
let digest = try app.password.hash("vapor")
```

### 异步 

密码散列算法被设计成慢速和CPU密集型。正因为如此，你可能想避免在密码散列时阻塞事件循环。Vapor提供了一个异步密码散列API，将散列分配到后台线程池。要使用异步API，请使用密码散列器的`async`属性。

```swift
req.password.async.hash("vapor").map { digest in
    // 处理摘要。
}

// 或

let digest = try await req.password.async.hash("vapor")
```

验证摘要的工作原理与此类似：

```swift
req.password.async.verify("vapor", created: digest).map { bool in
    // 处理结果。
}

// 或

let result = try await req.password.async.verify("vapor", created: digest)
```

在后台线程上计算哈希值可以释放你的应用程序的事件循环，以处理更多传入的请求。

