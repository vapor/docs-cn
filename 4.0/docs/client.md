# 客户端

Vapor的客户端API允许你调用外部HTTP资源。他是搭建在 [async-http-client](https://github.com/swift-server/async-http-client) 之上，并和 Vapor 的 [Content](./content.md) API 融入一体。

## 概述

你可以用过 `Application` 直接访问默认客户端，或者在一个路由里通过 `Request` 访问客户端。

```swift
app.client // Client

app.get("test") { req in
	req.client // Client
}
```

`Application` 的客户端适合在配置系统时访问外部HTTP资源。当你在路由里访问外部HTTP资源时，永远使用 `Request` 上的客户端。

### 方法

如果你想发送一个 `GET` 请求，你可以直接将 URL 传递给 `client` 的 `get` 方法。

```swift
req.client.get("https://httpbin.org/status/200").map { res in
	// 处理返回信息。
}
```

HTTP 的常用方法(例如 `get`, `post`, `delete`)全部都有快捷方法。客户端的答复会以一个 future 的形式返回，他包含了 HTTP 返回的状态，头，和内容。

### Content

你可以直接使用 Vapor 的 [Content](./content.md) API 处理需要发送和返回的数据。若想编码内容或者向请求添加参数，你可以使用  `beforeSend` 这个闭包。

```swift
req.client.post("https://httpbin.org/status/200") { req in
    // 往请求内容里添加参数 (?q=test)
	try req.query.encode(["q": "test"])

    // 往请求内容里添加JSON
    try req.content.encode(["hello": "world"])
}.map { res in
    // 处理返回的数据
}
```

你可以使用 `flatMapThrowing` 解码返回的内容

```swift
req.client.get("https://httpbin.org/json").flatMapThrowing { res in
	try res.content.decode(MyJSONResponse.self)
}.map { json in
	// 处理返回的JSON信息
}
```

## 配置

你可以通过 application 配置HTTP客户端参数。

```swift
// 禁止自动跳转
app.client.configuration.redirectConfiguration = .disallow
```

注意：你必须在第一次使用客户端之前配置参数。


