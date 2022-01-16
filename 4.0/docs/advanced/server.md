# Server

Vapor包括一个建立在[SwiftNIO](https://github.com/apple/swift-nio)上的高性能、异步的HTTP服务器。该服务器支持HTTP/1、HTTP/2以及[WebSockets](websockets.md)等协议的升级。该服务器还支持启用TLS（SSL）。

## 配置

Vapor的默认HTTP服务器可以通过`app.http.server`进行配置。

```swift
// 只支持HTTP/2
app.http.server.configuration.supportVersions = [.two]
```

HTTP服务器支持几个配置选项。

### 主机名

主机名控制服务器接受新连接的地址。默认是127.0.0.1。

```swift
// 配置自定义主机名。
app.http.server.configuration.hostname = "dev.local"
```

服务器配置的主机名可以通过向`serve`命令传递`--主机名`(`-H`)标志或向`app.server.start(...)`传递`主机名`参数来覆盖。

```sh
# 覆盖配置的主机名。
vapor run serve --hostname dev.local
```

### 端口

端口选项控制服务器在指定地址的哪个端口接受新的连接。默认是`8080`。

```swift
// 配置自定义端口。
app.http.server.configuration.port = 1337
```

!!! 信息
    绑定小于`1024`的端口可能需要`sudo`。不支持大于`65535`的端口。


服务器配置的端口可以通过向`serve`命令传递`--port`(`-p`)标志或向`app.server.start(..)`传递`port`参数来覆盖。

```sh
# 覆盖配置的端口。
vapor run serve --port 1337
```

### 积压

参数`backlog`定义了等待连接队列的最大长度。默认值是`256`。

```swift
// 配置自定义backlog.
app.http.server.configuration.backlog = 128
```

### 重用地址

`reuseAddress`参数允许重复使用本地地址。默认为`true`。

```swift
// 禁用地址重用。
app.http.server.configuration.reuseAddress = false
```

### TCP No Delay

启用`tcpNoDelay`参数将试图最小化TCP数据包的延迟。默认值为`true`。

```swift
// 尽量减少数据包延迟。
app.http.server.configuration.tcpNoDelay = true
```

### 响应压缩

`responseCompression`参数控制HTTP响应的压缩，使用gzip。默认是`.disabled`。

```swift
// 启用HTTP响应压缩.
app.http.server.configuration.responseCompression = .enabled
```

要指定一个初始缓冲区容量，请使用`initialByteBufferCapacity`参数。

```swift
.enabled(initialByteBufferCapacity: 1024)
```

### 请求解压

`requestDecompression`参数控制HTTP请求使用gzip进行解压。默认是`.disabled`。

```swift
// 启用HTTP请求解压。
app.http.server.configuration.requestDecompression = .enabled
```

要指定一个解压限制，使用`limit`参数。默认是`.ratio(10)`。

```swift
// 没有解压大小限制
.enabled(limit: .none)
```

可用的选项是。

- `size`：以字节为单位的最大解压尺寸。
- `ratio`：最大解压大小与压缩字节数的比率。
- `none`：没有大小限制。

设置解压大小限制可以帮助防止恶意压缩的HTTP请求使用大量的内存。

### Pipelining

`supportPipelining`参数允许支持HTTP请求和响应的管道化。默认是`false`. 

```swift
// 支持HTTP管道化.
app.http.server.configuration.supportPipelining = true
```

### 版本

`supportVersions`参数控制服务器将使用哪些HTTP版本。默认情况下，当启用TLS时，Vapor将同时支持HTTP/1和HTTP/2。当TLS被禁用时，只支持HTTP/1。

```swift
// 禁用HTTP/1支持。
app.http.server.configuration.supportVersions = [.two]
```

### TLS

`tlsConfiguration`参数控制服务器上是否启用TLS（SSL）。默认为`nil`。

```swift
// 启用TLS。
try app.http.server.configuration.tlsConfiguration = .forServer(
    certificateChain: NIOSSLCertificate.fromPEMFile("/path/to/cert.pem").map { .certificate($0) },
    privateKey: .file("/path/to/key.pem")
)
```

为了使这个配置能够编译，你需要在配置文件的顶部添加`import NIOSSL`。你也可能需要在你的Package.swift文件中把NIOSSL作为一个依赖项。

### 名称

`serverName`参数控制HTTP响应中的`Server`头。默认为`nil`。

```swift
// 在响应中添加'Server: vapor'头。
app.http.server.configuration.serverName = "vapor"
```

## Serve命令

要启动Vapor的服务器，使用`serve`命令。如果没有指定其他命令，该命令将默认运行。

```swift
vapor run serve
```

`serve`命令接受以下参数：

- `hostname` (`-H`)：覆盖配置的主机名。
- `port` (`-p`)：覆盖配置的端口。
- `bind`(`-b`)：覆盖配置的主机名和端口用`:`连接。

一个使用`-bind`(`-b`)标志的例子：

```swift
vapor run serve -b 0.0.0.0:80
```

使用`vapor run serve --help`获得更多信息。

`serve`命令将监听`SIGTERM`和`SIGINT`以优雅地关闭服务器。使用`ctrl+c`（`^c`）来发送`SIGINT`信号。当日志级别被设置为`debug'或更低时，关于优雅关机状态的信息将被记录下来。

## 手动启动

Vapor的服务器可以使用`app.server`手动启动。

```swift
// 启动Vapor的服务器。
try app.server.start()
// 要求服务器关闭。
app.server.shutdown()
// 等待服务器关机。
try app.server.onShutdown.wait()
```

## 服务器

Vapor使用的服务器是可配置的。默认情况下，使用内置的HTTP服务器。

```swift
app.servers.use(.http)
```

### 自定义服务器

Vapor的默认HTTP服务器可以被任何符合`Server`的类型所取代。

```swift
import Vapor

final class MyServer: Server {
    ...
}

app.servers.use { app in
    MyServer()
}
```

自定义服务器可以扩展`Application.Servers.Provider`，以获得领先的点状语法。

```swift
extension Application.Servers.Provider {
    static var myServer: Self {
        .init {
            $0.servers.use { app in
                MyServer()
            }
        }
    }
}

app.servers.use(.myServer)
```
