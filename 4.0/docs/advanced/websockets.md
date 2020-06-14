# WebSockets

[WebSockets](https://zh.wikipedia.org/wiki/WebSocket) 允许客户端和服务器之间进行双向通信。 与HTTP的请求和响应模式不同，WebSocket pears 可以在任一方向上发送任意数量的消息。 Vapor的WebSocket API允许您创建异步处理消息的客户端和服务器。

## 服务器

你可以使用Routing API 将 WebSocket endpoints 添加到现有的Vapor应用程序中。 使用 `webSocket` 的方法就像使用 `get` 或 `post` 一样。

```swift
app.webSocket("echo") { req, ws in
    // Connected WebSocket.
    print(ws)
}
```

WebSocket 路径可以像普通路由一样由中间件进行分组和保护。

除了接受 HTTP 请求之外，WebSocket 处理器还可以接受新建立的 WebSocket 连接。有关使用此 WebSocket 发送和阅读消息的更多信息，请参见下文。

## Client

To connect to a remote WebSocket endpoint, use `WebSocket.connect`. 

```swift
WebSocket.connect(to: "ws://echo.websocket.org", on: eventLoop) { ws in
    // Connected WebSocket.
    print(ws)
}
```

The `connect` method returns a future that completes when the connection is established. Once connected, the supplied closure will be called with the newly connected WebSocket. See below for more information on using this WebSocket to send and read messages.

## Messages

The `WebSocket` class has methods for sending and receiving messages as well as listening for events like closure. WebSockets can transmit data via two protocols: text and binary. Text messages are interpreted as UTF-8 strings while binary data is interpreted as an array of bytes.

### Sending

Messages can be sent using the WebSocket's `send` method.

```swift
ws.send("Hello, world")
```

Passing a `String` to this method results in a text message being sent. Binary messages can be sent by passing a `[UInt8]`. 

```swift
ws.send([1, 2, 3])
```

Message sending is asynchronous. You can supply an `EventLoopPromise` to the send method to be notified when the message has finished sending or failed to send. 

```swift
let promise = eventLoop.makePromise(of: Void.self)
ws.send(..., promise: promise)
promise.futureResult.whenComplete { result in
    // Succeeded or failed to send.
}
```

### Receiving

Incoming messages are handled via the `onText` and `onBinary` callbacks.

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

The WebSocket itself is supplied as the first parameter to these callbacks to prevent reference cycles. Use this reference to take action on the WebSocket after receiving data. For example, to send a reply:

```swift
// Echoes received messages.
ws.onText { ws, text in
    ws.send(text)
}
```

## Closing

To close a WebSocket, call the `close` method. 

```swift
ws.close()
```

This method returns a future that will be completed when the WebSocket has closed. Like `send`, you may also pass a promise to this method.

```swift
ws.close(promise: nil)
```

To be notified when the peer closes the connection, use `onClose`. This future will be completed when either the client or server closes the WebSocket.

```swift
ws.onClose.whenComplete { result in
    // Succeeded or failed to close.
}
```

The `closeCode` property is set when the WebSocket closes. This can be used to determine why the peer closed the connection.

## Ping / Pong

Ping and pong messages are sent automatically by the client and server to keep WebSocket connections alive. Your application can listen for these events using the `onPing` and `onPong` callbacks.

```swift
ws.onPing { ws in 
    // Ping was received.
}

ws.onPong { ws in
    // Pong was received.
}
```
