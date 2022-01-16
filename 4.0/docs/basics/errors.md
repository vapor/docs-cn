# 错误

Vapor基于Swift的`Error`协议进行错误处理。路由处理程序可以`throw`一个错误或返回一个失败的`EventLoopFuture`。抛出或返回一个Swift的`Error`将导致一个`500`状态响应，并且错误将被记录下来。`AbortError`和`DebuggableError`可以分别用来改变结果响应和记录。错误的处理是由`ErrorMiddleware`完成的。这个中间件默认被添加到应用程序中，如果需要的话，可以用自定义的逻辑来代替。

## 终止

Vapor提供了一个默认的错误结构，名为`Abort`。这个结构同时符合`AbortError`和`DebuggableError`。你可以用一个HTTP状态和可选的失败原因来初始化它。

```swift
// 404错误, 默认使用`未找到`原因.
throw Abort(.notFound)

// 401错误，使用自定义原因。
throw Abort(.unauthorized, reason: "Invalid Credentials")
```

在旧的异步情况下，不支持抛出，你必须返回一个`EventLoopFuture`，比如在`flatMap`闭包中，你可以返回一个失败的future。

```swift
guard let user = user else {
    req.eventLoop.makeFailedFuture(Abort(.notFound))    
}
return user.save()
```

Vapor包括一个辅助扩展，用于解包带有可选值的值：`unwrap(or:)`。

```swift
User.find(id, on: db)
    .unwrap(or: Abort(.notFound))
    .flatMap 
{ user in
    // Non-optional User supplied to closure.
}
```

如果`User.find`返回`nil`，未来将以提供的错误而失败。否则，`flatMap`将被提供一个非选择的值。如果使用`async`/`await`，那么你可以像平常一样处理选项。

```swift
guard let user = try await User.find(id, on: db) {
    throw Abort(.notFound)
}
```


## 终止错误

默认情况下，任何由路由闭包抛出或返回的Swift`Error`将导致`500 Internal Server Error`响应。当以调试模式构建时，`ErrorMiddleware`将包括错误的描述。当项目在发布模式下构建时，出于安全考虑，这将被剥离出来。

要配置一个特定错误的HTTP响应状态或原因，请将其与`AbortError`相符合。

```swift
import Vapor

enum MyError {
    case userNotLoggedIn
    case invalidEmail(String)
}

extension MyError: AbortError {
    var reason: String {
        switch self {
        case .userNotLoggedIn:
            return "User is not logged in."
        case .invalidEmail(let email):
            return "Email address is not valid: \(email)."
        }
    }

    var status: HTTPStatus {
        switch self {
        case .userNotLoggedIn:
            return .unauthorized
        case .invalidEmail:
            return .badRequest
        }
    }
}
```

## 可调试的错误

`ErrorMiddleware`使用`Logger.report(error:)`方法来记录由你的路由抛出的错误。该方法将检查是否符合`CustomStringConvertible`和`LocalizedError`等协议，以记录可读信息。

为了定制错误日志，你可以将你的错误与`DebuggableError`相符合。这个协议包括一些有用的属性，如唯一的标识符、源位置和堆栈跟踪。这些属性大多是可选的，这使得采用一致性很容易。

为了最好地符合`DebuggableError`，你的错误应该是一个结构，这样它就可以在需要时存储源和堆栈跟踪信息。下面是前面提到的`MyError`枚举的例子，它被更新为使用`struct`并捕获错误源信息。

```swift
import Vapor

struct MyError: DebuggableError {
    enum Value {
        case userNotLoggedIn
        case invalidEmail(String)
    }

    var identifier: String {
        switch self.value {
        case .userNotLoggedIn:
            return "userNotLoggedIn"
        case .invalidEmail:
            return "invalidEmail"
        }
    }

    var reason: String {
        switch self.value {
        case .userNotLoggedIn:
            return "User is not logged in."
        case .invalidEmail(let email):
            return "Email address is not valid: \(email)."
        }
    }

    var value: Value
    var source: ErrorSource?

    init(
        _ value: Value,
        file: String = #file,
        function: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        self.value = value
        self.source = .init(
            file: file,
            function: function,
            line: line,
            column: column
        )
    }
}
```

`DebuggableError`有几个其他属性，如`possibleCauses`和`suggestedFixes`，你可以用它们来提高错误的调试性。看一下协议本身，了解更多信息。

## 堆栈跟踪

Vapor包括对查看Swift正常错误和崩溃的堆栈跟踪的支持。

### Swift Backtrace

Vapor使用[SwiftBacktrace](https://github.com/swift-server/swift-backtrace)库来提供Linux上发生致命错误或断言后的堆栈跟踪。为了使其发挥作用，你的应用程序必须在编译时包含调试符号。

```sh
swift build -c release -Xswiftc -g
```

### 错误跟踪

默认情况下, `Abort`在初始化时将捕获当前的堆栈跟踪。你的自定义错误类型可以通过符合`DebuggableError`和存储`StackTrace.capture()`来实现。

```swift
import Vapor

struct MyError: DebuggableError {
    var identifier: String
    var reason: String
    var stackTrace: StackTrace?

    init(
        identifier: String,
        reason: String,
        stackTrace: StackTrace? = .capture()
    ) {
        self.identifier = identifier
        self.reason = reason
        self.stackTrace = stackTrace
    }
}
```

当你的应用程序的[日志级别](./logging.md#level)被设置为`.debug`或更低，错误的堆栈痕迹将被包含在日志输出中。

当日志级别大于`.debug`时，堆栈跟踪将不会被捕获。要覆盖这一行为，请在`configure`中手动设置`StackTrace.isCaptureEnabled`。

```swift
// 始终捕获堆栈跟踪，无论日志级别如何。
StackTrace.isCaptureEnabled = true
```

## 错误中间件

`ErrorMiddleware`是默认添加到你的应用程序的唯一中间件。这个中间件将你的路由处理程序抛出或返回的Swift错误转换为HTTP响应。如果没有这个中间件，抛出的错误将导致连接被关闭而没有响应。

要想在`AbortError`和`DebuggableError`之外定制错误处理，你可以用你自己的错误处理逻辑替换`ErrorMiddleware`。要做到这一点，首先通过设置`app.middleware`到一个空的配置来删除默认的错误中间件。然后，添加你自己的错误处理中间件作为你的应用程序的第一个中间件。

```swift
// 删除所有现有的中间件。
app.middleware = .init()
// 首先添加自定义错误处理中间件。
app.middleware.use(MyErrorMiddleware())
```

很少有中间件应该走在错误处理中间件之前。这个规则的一个明显的例外是`CORSMiddleware`。
