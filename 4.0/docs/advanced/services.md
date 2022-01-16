# 服务

Vapor的`Application`和`Request`是为你的应用和第三方包的扩展而建立的。添加到这些类型的新功能通常被称为服务。

## 只读

最简单的服务类型是只读的。这些服务由添加到应用程序或请求中的计算变量或方法组成。

```swift
import Vapor

struct MyAPI {
    let client: Client

    func foos() async throws -> [String] { ... }
}

extension Request {
    var myAPI: MyAPI {
        .init(client: self.client)
    }
}
```

只读服务可以依赖于任何预先存在的服务，比如本例中的`client`。一旦扩展被添加，你的自定义服务可以像其他属性一样按要求使用。

```swift
req.myAPI.foos()
```

## 可写

需要状态或配置的服务可以利用`Application`和`Request`存储来存储数据。让我们假设你想在你的应用程序中添加以下`MyConfiguration`结构。

```swift
struct MyConfiguration {
    var apiKey: String
}
```

要使用存储，你必须声明一个`StorageKey`。

```swift
struct MyConfigurationKey: StorageKey {
    typealias Value = MyConfiguration
}
```

这是一个空结构，有一个`Value`类型的别名，指定被存储的类型。通过使用一个空类型作为键，你可以控制哪些代码能够访问你的存储值。如果该类型是内部或私有的，那么只有你的代码能够修改存储中的相关值。

最后，给`Application`添加一个扩展，用于获取和设置`MyConfiguration`结构。

```swift
extension Application {
    var myConfiguration: MyConfiguration? {
        get {
            self.storage[MyConfigurationKey.self]
        }
        set {
            self.storage[MyConfigurationKey.self] = newValue
        }
    }
}
```

一旦扩展被添加，你就可以像使用`Application`的普通属性一样使用`myConfiguration`。


```swift
app.myConfiguration = .init(apiKey: ...)
print(app.myConfiguration?.apiKey)
```

## 生命周期

Vapor的`Application`允许你注册生命周期处理程序。这些处理程序可以让你钩住诸如启动和关机等事件。

```swift
// 在启动过程中打印出Hello。
struct Hello: LifecycleHandler {
    // 在应用程序启动前调用。
    func willBoot(_ app: Application) throws {
        app.logger.info("Hello!")
    }
}

// 添加生命周期处理程序。
app.lifecycle.use(Hello())
```

## 锁定

Vapor的`Application`包括使用锁来同步代码的便利性。通过声明一个`LockKey`，你可以得到一个唯一的、共享的锁来同步访问你的代码。

```swift
struct TestKey: LockKey { }

let test = app.locks.lock(for: TestKey.self)
test.withLock {
    // 做点什么。
}
```

每次调用`lock(for:)`时，使用相同的`LockKey`将返回同一个锁。这个方法是线程安全的。

对于一个应用程序范围内的锁，你可以使用`app.sync`。

```swift
app.sync.withLock {
    // 做点什么。
}
```

## 请求

打算在路由处理程序中使用的服务应该被添加到`Request`中。请求服务应该使用请求的记录器和事件循环。重要的是，请求应保持在同一事件循环中，否则当响应返回到Vapor时，会有一个断言被击中。

如果一个服务必须离开请求的事件循环来进行工作，它应该确保在完成之前返回到事件循环中。这可以使用`EventLoopFuture`上的`hop(to:)`来实现。

需要访问应用服务的请求服务，如配置，可以使用`req.application`。当从路由处理程序访问应用程序时，要注意考虑线程安全。一般来说，只有读操作应该由请求执行。写操作必须有锁的保护。
