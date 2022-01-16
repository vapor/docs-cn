# 异步

## 异步等待

Swift 5.5以`async`/`await`的形式为语言引入了并发性。这为处理Swift和Vapor应用程序中的异步代码提供了一种一流的方式。

Vapor建立在[SwiftNIO](https://github.com/apple/swift-nio.git)之上，它为低层异步编程提供了原始类型。在`async`/`await `出现之前，这些类型已经（并且仍然）在整个Vapor中使用。然而，大多数应用程序的代码现在可以使用`async`/`await`来编写，而不是使用`EventLoopFuture`。这将简化你的代码，使其更容易推理。

现在Vapor的大多数API都提供了`EventLoopFuture`和`async`/`await`两个版本，供你选择哪一个最好。一般来说，你应该在每个路由处理程序中只使用一种编程模型，而不是在你的代码中混合使用。对于需要明确控制事件循环的应用程序，或非常高性能的应用程序，你应该继续使用`EventLoopFuture`，直到自定义执行器被实现。对于其他人，你应该使用`async`/`await`，因为可读性和可维护性的好处远远超过了任何小的性能损失。

### 迁移到async/await

迁移到async/await需要几个步骤。首先，如果使用macOS，你必须在macOS 12 Monterey或更高版本和Xcode 13.1或更高版本。对于其他平台，你需要运行Swift 5.5或更高版本。接下来，确保你已经更新了所有的依赖性。

在你的Package.swift中，在文件的顶部将工具版本设置为5.5：

```swift
// swift-tools-version:5.5
import PackageDescription

// ...
```

接下来，将平台版本设置为macOS 12：

```swift
    platforms: [
       .macOS(.v12)
    ],
```

最后更新`Run`目标，将其标记为可执行目标：

```swift
.executableTarget(name: "Run", dependencies: [.target(name: "App")]),
```

注意：如果你在Linux上部署，请确保你也在那里更新Swift的版本，例如在Heroku或你的Docker文件中。例如，你的Dockerfile应改为：

```diff
-FROM swift:5.2-focal as build
+FROM swift:5.5-focal as build
...
-FROM swift:5.2-focal-slim
+FROM swift:5.5-focal-slim
```

现在你可以迁移现有的代码了。一般来说，返回`EventLoopFuture`的函数现在是`async`。比如说：

```swift
routes.get("firstUser") { req -> EventLoopFuture<String> in
    User.query(on: req.db).first().unwrap(or: Abort(.notFound)).flatMap { user in
        user.lastAccessed = Date()
        return user.update(on: req.db).map {
            return user.name
        }
    }
}
```

现在变成了：

```swift
routes.get("firstUser") { req async throws -> String in
    guard let user = try await User.query(on: req.db).first() else {
        throw Abort(.notFound)
    }
    user.lastAccessed = Date()
    try await user.update(on: req.db)
    return user.name
}
```

### 与新旧API合作

如果你遇到的API还没有提供`async`/`await`版本，你可以在返回`EventLoopFuture`的函数上调用`.get()`来转换。

例如。

```swift
return someMethodCallThatReturnsAFuture().flatMap { futureResult in
    // use futureResult
}
```

可以成为

```swift
let futureResult = try await someMethodThatReturnsAFuture().get()
```

如果你需要反其道而行之，你可以转换

```swift
let myString = try await someAsyncFunctionThatGetsAString()
```

为

```swift
let promise = request.eventLoop.makePromise(of: String.self)
promise.completeWithTask {
    try await someAsyncFunctionThatGetsAString()
}
let futureString: EventLoopFuture<String> = promise.futureResult
```

## 事件循环功能

你可能已经注意到Vapor的一些API期望或返回一个通用的`EventLoopFuture`类型。如果这是你第一次听到期货，它们一开始可能会有点混乱。但不要担心，本指南将告诉你如何利用它们强大的API。

许诺和期货是相关的，但又是不同的类型。许诺用于_创建_期货。大多数情况下，你将使用Vapor的API返回的期货，你不需要担心创建诺言。

|类型|描述|可变性|
|-|-|-|
|`EventLoopFuture`|对一个可能还不能使用的值的引用。|只读|
|`EventLoopPromise`|一个异步提供一些值的承诺。|读/写|

Futures是基于回调的异步API的替代品。期货可以以简单闭包的方式进行链式和转换。

## 转换

就像Swift中的选项和数组一样，期货可以被map和flatMap。这些是你在期货上最常执行的操作。

|方法|参数|描述|
|-|-|-|
|[`map`](#map)|`(T) -> U`|将一个未来值映射到一个不同的值。|
|[`flatMapThrowing`](#flatmapthrowing)|`(T) throws -> U`|将一个未来值映射到一个不同的值或一个错误。|
|[`flatMap`](#flatmap)|`(T) -> EventLoopFuture<U>`|将一个未来值映射到不同的未来值。|
|[`transform`](#transform)|`U`|将一个未来映射到一个已经可用的值。|

如果你看一下`Optional<T>`和`Array<T>`上的`map`和`flatMap`的方法签名，你会发现它们与`EventLoopFuture<T>`上的方法非常相似。

### map

`map`方法允许你将未来的值转换为另一个值。因为未来的值可能还不可用（它可能是一个异步任务的结果），我们必须提供一个闭包来接受这个值。

```swift
/// 假设我们从某个API得到一个未来的字符串
let futureString: EventLoopFuture<String> = ...

/// 将未来的字符串映射为一个整数
let futureInt = futureString.map { string in
    print(string) // The actual String
    return Int(string) ?? 0
}

/// 我们现在有了一个未来的整数
print(futureInt) // EventLoopFuture<Int>
```

### flatMapThrowing

`flatMapThrowing`方法允许你将未来的值转换为另一个值或者抛出一个错误。

!!! info
    因为抛出一个错误必须在内部创建一个新的未来值，所以这个方法的前缀是`flatMap`，尽管闭包不接受未来的返回。

```swift
/// 假设我们从某个API得到一个未来的字符串
let futureString: EventLoopFuture<String> = ...

/// 将未来的字符串映射为一个整数
let futureInt = futureString.flatMapThrowing { string in
    print(string) // 实际的字符串
    // 将字符串转换为整数，否则抛出一个错误
    guard let int = Int(string) else {
        throw Abort(...)
    }
    return int
}

/// 我们现在有了一个未来的整数
print(futureInt) // EventLoopFuture<Int>
```

### flatMap

`flatMap`方法允许你将future的值转换为另一个未来的值。它之所以被称为"flat"映射，是因为它可以让你避免创建嵌套的期货（例如，`EventLoopFuture<EventLoopFuture<T>>`）。换句话说，它可以帮助你保持你的泛型的扁平。

```swift
/// 假设我们从某个API中得到一个未来的字符串回来
let futureString: EventLoopFuture<String> = ...

/// 假设我们已经创建了一个HTTP客户端
let client: Client = ... 

/// 将未来字符串flatMap到未来响应上
let futureResponse = futureString.flatMap { string in
    client.get(string) // EventLoopFuture<ClientResponse>
}

/// 我们现在有了一个未来的回应
print(futureResponse) // EventLoopFuture<ClientResponse>
```

!!! info
    如果我们在上面的例子中改用`map`，我们就会变成：`EventLoopFuture<EventLoopFuture<ClientResponse>>`。

要在`flatMap`中调用一个抛出方法，请使用Swift的`do`/`catch`关键字，并创建一个[已完成的未来](#makefuture)。

```swift
/// 假设前面的例子中的未来字符串和客户端。
let futureResponse = futureString.flatMap { string in
    let url: URL
    do {
        // 一些同步抛出的方法。
        url = try convertToURL(string)
    } catch {
        // 使用事件循环来制作预完成的未来。
        return eventLoop.makeFailedFuture(error)
    }
    return client.get(url) // EventLoopFuture<ClientResponse>
}
```
    
### 转换

`transform`方法允许你修改一个future的值，忽略现有的值。这对于转换`EventLoopFuture<Void>`的结果特别有用，因为未来的实际值并不重要。

!!! tip
    `EventLoopFuture<Void>`，有时也称为信号，是一个未来，其唯一目的是通知你一些异步操作的完成或失败。

```swift
/// 假设我们从某个API中得到一个无效的未来。
let userDidSave: EventLoopFuture<Void> = ...

/// 将无效的未来转换为HTTP状态
let futureStatus = userDidSave.transform(to: HTTPStatus.ok)
print(futureStatus) // EventLoopFuture<HTTPStatus>
```   

即使我们为`transform`提供了一个已经可用的值，这仍然是一个转换。在所有先前的期货完成（或失败）之前，该期货不会完成。

### 链式

期货上的转换最棒的地方是它们可以被链起来。这允许你轻松地表达许多转换和子任务。

让我们修改上面的例子，看看我们如何利用链式的优势。

```swift
/// 假设我们从某个API得到一个未来的字符串
let futureString: EventLoopFuture<String> = ...

/// 假设我们已经创建了一个HTTP客户端
let client: Client = ... 

/// 将字符串转换为一个网址，然后再转换为一个响应
let futureResponse = futureString.flatMapThrowing { string in
    guard let url = URL(string: string) else {
        throw Abort(.badRequest, reason: "Invalid URL string: \(string)")
    }
    return url
}.flatMap { url in
    client.get(url)
}

print(futureResponse) // EventLoopFuture<ClientResponse>
```

在初始调用map后，有一个临时的`EventLoopFuture<URL>`被创建。然后这个未来会被立即平铺到一个`EventLoopFuture<Response>`中。
    
## Future

让我们来看看其他一些使用`EventLoopFuture<T>`的方法。

### makeFuture

你可以使用一个事件循环来创建预完成的未来，其中包括值或错误。

```swift
// 创建一个预成功的未来。
let futureString: EventLoopFuture<String> = eventLoop.makeSucceededFuture("hello")

// 创建一个预先失败的未来。
let futureString: EventLoopFuture<String> = eventLoop.makeFailedFuture(error)
```

### whenComplete


你可以使用`whenComplete`来添加一个回调，在未来成功或失败时执行。

```swift
/// 假设我们从某个API得到一个Future的字符串
let futureString: EventLoopFuture<String> = ...

futureString.whenComplete { result in
    switch result {
    case .success(let string):
        print(string) // The actual String
    case .failure(let error):
        print(error) // A Swift Error
    }
}
```

!!! note
    你可以为一个未来添加任意多的回调。
    
### Wait

你可以使用`.wait()`来同步地等待未来的完成。由于未来可能会失败，这个调用是抛出的。

```swift
/// 假设我们从某个API得到一个Future的字符串
let futureString: EventLoopFuture<String> = ...

/// 阻断，直到字符串准备好
let string = try futureString.wait()
print(string) /// String
```

`wait()`只能在后台线程或主线程上使用，即在`configure.swift`中。它不能在事件循环线程上使用，即在路由关闭中。

!!! warning
    试图在一个事件循环线程上调用`wait()`将导致断言失败。

    
## Promise

大多数情况下，你将转换调用Vapor的API所返回的期货。然而，在某些时候，你可能需要创建一个自己的承诺。

要创建一个承诺，你需要访问一个`EventLoop`。根据上下文，你可以从`Application`或`Request`获得对事件循环的访问。

```swift
let eventLoop: EventLoop 

// 为某个字符串创建一个新的Promise。
let promiseString = eventLoop.makePromise(of: String.self)
print(promiseString) // EventLoopPromise<String>
print(promiseString.futureResult) // EventLoopFuture<String>

// 完成相关的未来。
promiseString.succeed("Hello")

// 失败的相关未来。
promiseString.fail(...)
```

!!! info
    一个承诺只能被完成一次。任何后续的完成都将被忽略。

承诺可以从任何线程完成（`成功`/`失败`）。这就是为什么承诺需要一个事件循环被初始化。许诺确保完成动作被返回到其事件循环中执行。

## 事件循环

当你的应用程序启动时，它通常会为它所运行的CPU的每个核心创建一个事件循环。每个事件循环正好有一个线程。如果你熟悉Node.js中的事件循环，Vapor中的事件循环是类似的。主要区别在于，Vapor可以在一个进程中运行多个事件循环，因为Swift支持多线程。

每次客户端连接到你的服务器时，它将被分配到其中一个事件循环。从那时起，服务器和该客户之间的所有通信都将发生在同一个事件循环上（以及通过关联，该事件循环的线程）。

事件循环负责跟踪每个连接的客户端的状态。如果有一个来自客户端的请求等待被读取，事件循环会触发一个读取通知，导致数据被读取。一旦整个请求被读取，任何等待该请求数据的期货将被完成。

在路由闭包中，你可以通过`Request`访问当前的事件循环。

```swift
req.eventLoop.makePromise(of: ...)
```

!!! warning
    Vapor期望路由关闭将停留在`req.eventLoop`上。如果你跳线程，你必须确保对`Request`的访问和最终的响应未来都发生在请求的事件循环上。

在路由关闭之外，你可以通过`Application`获得可用的事件循环之一。

```swift
app.eventLoopGroup.next().makePromise(of: ...)
```

### hop

你可以使用`hop`来改变一个未来的事件循环。

```swift
futureString.hop(to: otherEventLoop)
```

## Blocking

在事件循环线程上调用阻塞代码会使你的应用程序无法及时响应传入的请求。阻塞调用的一个例子是`libc.sleep(_:)`之类的。

```swift
app.get("hello") { req in
    /// 让事件循环的线程进入睡眠状态。
    sleep(5)
    
    /// 一旦线程重新唤醒，返回一个简单的字符串。
    return "Hello, world!"
}
```

`sleep(_:)`是一个命令，它可以阻断当前线程所提供的秒数。如果你直接在事件循环上做这样的阻塞工作，那么在阻塞工作期间，事件循环将无法响应分配给它的任何其他客户端。换句话说，如果你在一个事件循环上做`sleep(5)`，所有连接到该事件循环的其他客户端（可能是成百上千）将被延迟至少5秒。

确保在后台运行任何阻塞性工作。当这项工作以非阻塞的方式完成时，使用承诺来通知事件循环。

```swift
app.get("hello") { req -> EventLoopFuture<String> in
    /// 派遣一些工作在后台线程上发生
    return req.application.threadPool.runIfActive(eventLoop: req.eventLoop) {
        /// 让背景线程进入睡眠状态
        /// 这不会影响任何事件循环。
        sleep(5)
        
        /// 当"阻塞工作"完成后。
        /// 返回结果。
        return "Hello world!"
    }
}
```

并非所有的阻塞调用都会像`sleep(_:)`那样明显。如果你怀疑你正在使用的某个调用可能是阻塞的，请研究该方法本身或询问他人。下面的章节将更详细地介绍方法如何阻塞。

### I/O绑定

I/O绑定阻塞是指在网络或硬盘等慢速资源上等待，这些资源的速度可能比CPU慢几个数量级。在你等待这些资源的时候阻塞CPU会导致时间的浪费。

!!! danger
    永远不要在事件循环上直接进行阻塞式I/O绑定调用。

Vapor的所有软件包都建立在SwiftNIO之上，使用非阻塞式I/O。然而，在野外有许多Swift包和C库都使用阻塞式I/O。如果一个函数正在进行磁盘或网络IO，并且使用同步API（没有回调或期货），它很可能是阻塞的。
    
### CPU绑定

请求期间的大部分时间都是在等待外部资源，如数据库查询和网络请求的加载。因为Vapor和SwiftNIO是非阻塞的，所以这段停机时间可以用来满足其他传入的请求。然而，你的应用程序中的一些路由可能需要做繁重的CPU绑定工作，作为请求的结果。

当一个事件循环正在处理CPU约束的工作时，它将无法响应其他传入的请求。这通常是好的，因为CPU是快速的，而且大多数网络应用的CPU工作是轻量级的。但是，如果有长期运行的CPU工作的路由阻碍了对快速路由的请求的快速响应，这就会成为一个问题。

识别你的应用程序中长期运行的CPU工作，并将其转移到后台线程，可以帮助改善你的服务的可靠性和响应性。与I/O绑定的工作相比，CPU绑定的工作更像是一个灰色地带，最终由你来决定你想在哪里划清界限。

在用户注册和登录过程中，Bcrypt的散列工作是一个常见的CPU约束工作的例子。为了安全起见，Bcrypt故意做得很慢，而且CPU密集。这可能是一个简单的Web应用程序实际做的最密集的CPU工作。将哈希运算转移到后台线程，可以让CPU在计算哈希运算时交错进行事件循环工作，从而获得更高的并发性。
