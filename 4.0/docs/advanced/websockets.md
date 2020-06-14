# WebSockets

[WebSockets](https://zh.wikipedia.org/wiki/WebSocket) 允许客户端和服务器之间进行双向通信。 与HTTP的请求和响应模式不同，WebSocket pears 可以在任意方向上发送任意数量的消息。 Vapor的WebSocket API允许你创建异步处理消息的客户端和服务器。

## 服务器

你可以使用Routing API 将 WebSocket endpoints 添加到现有的 Vapor 应用程序中。 使用 `webSocket` 的方法就像使用 `get` 或 `post` 一样。

```swift
app.webSocket("echo") { req, ws in
    // Connected WebSocket.
    print(ws)
}
```

WebSocket 路由可以像普通路由一样由中间件进行分组和保护。

除了接受 HTTP 请求之外，WebSocket 处理器还可以接受新建立的 WebSocket 连接。有关使用此 WebSocket 发送和阅读消息的更多信息，请参考下文。

## 客户端

要连接到远程 WebSocket 端口，请使用 `WebSocket.connect` 。

```swift
WebSocket.connect(to: "ws://echo.websocket.org", on: eventLoop) { ws in
    // Connected WebSocket.
    print(ws)
}
```

`connect` 方法返回建立连接后完成的 future。 连接后将使用新连接的 WebSocket 调用提供的闭包。有关使用 WebSocket 发送和阅读消息的更多信息，请参见下文。

## 消息

`WebSocket` 类具有发送和接收消息以及侦听如闭包的方法。 WebSocket 可以通过两种协议传输数据：文本以及二进制。 文本消息应当为 UTF-8 字符串，而二进制数据应当为字节数组。

### 发送

可以使用 WebSocket 的 `send` 方法来发送消息。

```swift
ws.send("Hello, world")
```

将 `String` 传递给此方法即可发送文本消息。二进制消息可以通过传递 `[UInt8]` 来发送。

```swift
ws.send([1, 2, 3])
```

消息发送是异步的。你可以向send方法提供一个 `EventLoopPromise` 以便在消息完成发送或发送失败时得到通知。

```swift
let promise = eventLoop.makePromise(of: Void.self)
ws.send(..., promise: promise)
promise.futureResult.whenComplete { result in
    // Succeeded or failed to send.
}
```

### 接收

接收的消息通过 `onText` 和 `onBinary` 回调进行处理。

```swift
ws.onText { ws, text in
    // String received by this WebSocket.
    print(text)
}

ws.onBinary { ws, binary in
    // [UInt8] received by this WebSocket.
    print(binary)
}
```

WebSocket本身作为这些回调的第一个参数提供来防止引用循环。接收数据后，使用此引用对WebSocket采取操作。例如，发送回复：

```swift
// Echoes received messages.
ws.onText { ws, text in
    ws.send(text)
}
```

## 关闭

如果要关闭 WebSocket ，请调用 `close` 方法。

```swift
ws.close()
```

该方法返回的 future 将在WebSocket关闭时完成。你也可以像“发送”一样向该方法传递一个 promise。

```swift
ws.close(promise: nil)
```

要在对方关闭连接时收到通知，请使用 `onClose`。 当客户端或服务器关闭WebSocket时，这个 future 将完成。

```swift
ws.onClose.whenComplete { result in
    // Succeeded or failed to close.
}
```

当WebSocket关闭时会设置 `closeCode` 属性。这可用于确定对方为什么关闭连接。

## Ping / Pong

客户端和服务器会自动发送 ping 和 pong 消息，来保持 WebSocket 的连接。你的程序可以使用 `onPing` 和 `onPong` 回调监听这些事件。

```swift
ws.onPing { ws in 
    // Ping was received.
}

ws.onPong { ws in
    // Pong was received.
}
```
