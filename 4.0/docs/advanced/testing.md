# 测试

Vapor 包含一个名为 `XCTVapor` 的模块，它提供了基于 `XCTest` 的测试帮助程序。这些测试帮助程序允许你以编程方式或通过HTTP服务器将测试请求发送至 Vapor 应用程序。

## 入门

要使用 `XCTVapor` 模块，请确保它已经被添加到你的测试目标的包中。

```swift
let package = Package(
    ...
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0")
    ],
    targets: [
        ...
        .testTarget(name: "AppTests", dependencies: [
            .target(name: "App"),
            .product(name: "XCTVapor", package: "vapor"),
        ])
    ]
)
```

然后，在测试文件的顶部添加 `import XCTVapor`。创建扩展 `XCTestCase` 的类来编写测试用例。

```swift
import XCTVapor

final class MyTests: XCTestCase {
    func testStub() throws {
    	// 在这里测试。
    }
}
```

当你的应用程序被测试时，每个以 `test` 开头的函数都会自动运行。

### 运行测试

在选择了 `Package` 方案的情况下，使用 `cmd+u` 在Xcode中运行测试。
或使用 `swift test --enable-test-discovery` 通过CLI进行测试。

## 可测试的应用程序

使用 `.testing` 环境初始化一个 `Application` 实例。你必须在这个应用程序停止初始化之前调用 `app.shutdown()`。

```swift
let app = Application(.testing)
defer { app.shutdown() }
try configure(app)
```

将 `Application` 传到包的 `configure(_:)` 方法来应用你的配置。之后可以应用到任何仅测试的配置。

### 发送请求

要向你的应用程序发送一个测试请求，请使用 `test ` 方法。

```swift
try app.test(.GET, "hello") { res in
    XCTAssertEqual(res.status, .ok)
    XCTAssertEqual(res.body.string, "Hello, world!")
}
```

前两个参数是HTTP方法和请求的URL。后面的尾随闭包接受HTTP响应，你可以使用 `XCTAssert` 方法进行验证。

对于更复杂的请求，你可以提供一个 `beforeRequest` 闭包来修改标题或编码内容。Vapor 的[Content API](.../basics/content.md) 可以在测试请求和响应中使用。

```swift
try app.test(.POST, "todos", beforeRequest: { req in
	try req.content.encode(["title": "Test"])
}, afterResponse: { res in
    XCTAssertEqual(res.status, .created)
    let todo = try res.content.decode(Todo.self)
    XCTAssertEqual(todo.title, "Test")
})
```

### 可测试的方法

Vapor的测试API支持以编程方式并通过实时HTTP服务器发送测试请求。
你可以通过使用 `testable` 方法来指定您想要使用的方法。

```swift
// 使用程序化测试。
app.testable(method: .inMemory).test(...)

// 通过一个实时的HTTP服务器运行测试。
app.testable(method: .running).test(...)
```

默认情况下使用 `inMemory` 选项。

`running` 选项支持传递一个特定的端口来使用。默认情况下使用的是 `8080`。

```swift
.running(port: 8123)
```

