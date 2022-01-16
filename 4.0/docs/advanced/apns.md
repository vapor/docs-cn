# APNS

Vapor的苹果推送通知服务（APNS）API使认证和发送推送通知到苹果设备变得容易。它建立在[APNSwift](https://github.com/kylebrowning/APNSwift)的基础上。

## 开始使用

让我们来看看你如何开始使用APNS。

### Package

使用APNS的第一步是将软件包添加到你的依赖项中。

```swift
// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "my-app",
    dependencies: [
         // 其他的依赖性...
        .package(url: "https://github.com/vapor/apns.git", from: "2.0.0"),
    ],
    targets: [
        .target(name: "App", dependencies: [
            // 其他的依赖性...
            .product(name: "APNS", package: "apns")
        ]),
        // Other targets...
    ]
)
```

如果您在Xcode中直接编辑清单，它将会自动接收更改并在保存文件时获取新的依赖关系。否则，从终端运行`swift package resolve`来获取新的依赖关系。

### 配置

APNS模块为`Application`添加了一个新的属性`apns`。为了发送推送通知，你需要用你的证书设置`configuration`属性。

```swift
import APNS

// 使用JWT认证配置APNS。
app.apns.configuration = try .init(
    authenticationMethod: .jwt(
        key: .private(filePath: <#path to .p8#>),
        keyIdentifier: "<#key identifier#>",
        teamIdentifier: "<#team identifier#>"
    ),
    topic: "<#topic#>",
    environment: .sandbox
)
```

在占位符中填入你的凭证。上面的例子显示了[基于JWT的认证](https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server/establishing_a_token-based_connection_to_apns)，使用你从苹果的开发者门户获得的`.p8`密钥。对于带有证书的[基于TLS的认证](https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server/establishing_a_certificate-based_connection_to_apns)，使用`.tls`认证方法。

```swift
authenticationMethod: .tls(
    privateKeyPath: <#path to private key#>,
    pemPath: <#path to pem file#>,
    pemPassword: <#optional pem password#>
)
```

### 发送

一旦配置了APNS，你可以使用`apns.send`方法在`Application`或`Request`上发送推送通知。

```swift
// 发送一个推送通知。
try app.apns.send(
    .init(title: "Hello", subtitle: "This is a test from vapor/apns"),
    to: "98AAD4A2398DDC58595F02FA307DF9A15C18B6111D1B806949549085A8E6A55D"
).wait()

// 或
try await app.apns.send(
    .init(title: "Hello", subtitle: "This is a test from vapor/apns"),
    to: "98AAD4A2398DDC58595F02FA307DF9A15C18B6111D1B806949549085A8E6A55D"
)
```

只要你在路由处理程序中，就使用`req.apns`。

```swift
// 发送一个推送通知。
app.get("test-push") { req -> EventLoopFuture<HTTPStatus> in
    req.apns.send(..., to: ...)
        .map { .ok }
}

// 或
app.get("test-push") { req async throws -> HTTPStatus in
    try await req.apns.send(..., to: ...) 
    return .ok
}
```

第一个参数接受推送通知警报，第二个参数是目标设备令牌。

## 警报

`APNSwiftAlert`是要发送的推送通知警报的实际元数据。关于每个属性的具体细节[这里](https://developer.apple.com/library/archive/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/PayloadKeyReference.html)。它们遵循苹果文档中列出的一对一的命名方案

```swift
let alert = APNSwiftAlert(
    title: "Hey There", 
    subtitle: "Full moon sighting", 
    body: "There was a full moon last night did you see it"
)
```

这种类型可以直接传递给`send`方法，它将被自动包裹在`APNSwiftPayload`中。

### Payload

`APNSwiftPayload`是推送通知的元数据。诸如警报、徽章数量等内容。关于每个属性的具体细节都提供了[这里](https://developer.apple.com/library/archive/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/PayloadKeyReference.html)。它们遵循苹果文档中列出的一对一的命名方案

```swift
let alert = ...
let aps = APNSwiftPayload(alert: alert, badge: 1, sound: .normal("cow.wav"))
```

这可以传递给`send`方法。

### 自定义通知数据

苹果公司为工程师提供了在每个通知中添加自定义有效载荷数据的能力。为了方便这一点，我们有`APNSwiftNotification`。

```swift
struct AcmeNotification: APNSwiftNotification {
    let acme2: [String]
    let aps: APNSwiftPayload

    init(acme2: [String], aps: APNSwiftPayload) {
        self.acme2 = acme2
        self.aps = aps
    }
}

let aps: APNSwiftPayload = ...
let notification = AcmeNotification(acme2: ["bang", "whiz"], aps: aps)
```

这个自定义的通知类型可以被传递给`send`方法。

## 更多信息

关于可用方法的更多信息，请参阅[APNSwift的README](https://github.com/kylebrowning/APNSwift)。
