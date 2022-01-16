# 认证

认证是验证用户身份的行为。这是通过验证用户名和密码或独特的令牌等凭证来完成的。认证（有时称为auth/c）与授权（auth/z）不同，后者是验证先前认证的用户执行某些任务的权限的行为。

## 介绍

Vapor的认证API支持通过`Authorization`头对用户进行认证，使用[基本](https://tools.ietf.org/html/rfc7617)和[承载](https://tools.ietf.org/html/rfc6750)。它还支持通过从[Content](/content.md)API解码的数据来验证用户。

认证是通过创建一个包含验证逻辑的`Authenticator`来实现的。一个认证器可以用来保护单个路由组或整个应用程序。以下是Vapor提供的认证器辅助工具。

|协议|描述|
|-|-|
|`RequestAuthenticator`/`AsyncRequestAuthenticator`|能够创建中间件的基础认证器。|
|[`BasicAuthenticator`/`AsyncBasicAuthenticator`](#basic)|验证基本授权头。|
|[`BearerAuthenticator`/`AsyncBearerAuthenticator`](#bearer)|验证承载器授权头。|
|`CredentialsAuthenticator`/`AsyncCredentialsAuthenticator`|从请求体中认证一个证书有效载荷。|

如果认证成功，认证器会将经过验证的用户添加到`req.auth`中。然后可以使用`req.auth.get(_:)`在认证器保护的路由中访问这个用户。如果认证失败，该用户不会被添加到`req.auth`中，任何访问该用户的尝试都会失败。

## 可认证的

要使用认证API，你首先需要一个符合`Authenticatable`的用户类型。这可以是一个`struct`，`class`，甚至是一个Fluent`Model`。下面的例子假设这个简单的`User`结构有一个属性：`name`。

```swift
import Vapor

struct User: Authenticatable {
    var name: String
}
```

下面的每个例子都将使用我们创建的认证器的一个实例。在这些例子中，我们称它为`UserAuthenticator`。

### 路线

认证器是中间件，可用于保护路由。

```swift
let protected = app.grouped(UserAuthenticator())
protected.get("me") { req -> String in
    try req.auth.require(User.self).name
}
```

`req.auth.require`用于获取认证的`User`。如果认证失败，该方法将抛出一个错误，保护路线。

### Guard Middleware

你也可以在你的路由组中使用`GuardMiddleware`来确保用户在到达你的路由处理程序之前已经被认证了。

```swift
let protected = app.grouped(UserAuthenticator())
    .grouped(User.guardMiddleware())
```

要求认证者中间件不做认证，以允许认证者的组成。请阅读下面关于[组合](#composition)的更多信息。

## 基本

基本认证在`Authorization`头中发送一个用户名和密码。用户名和密码用冒号连接(例如`test:secret`), 以base-64编码, 并以`"Basic"`为前缀。下面的请求示例对用户名`test`和密码`secret`进行编码。

```http
GET /me HTTP/1.1
Authorization: Basic dGVzdDpzZWNyZXQ=
``` 

基本认证通常只用一次，用于登录用户并生成一个令牌。这就最大限度地减少了必须发送用户敏感密码的频率。你不应该通过明文或未经验证的TLS连接发送基本授权。

要在你的应用程序中实现基本认证，创建一个符合`BasicAuthenticator`的新认证器。下面是一个硬编码的认证器例子，用来验证上面的请求。


```swift
import Vapor

struct UserAuthenticator: BasicAuthenticator {
    typealias User = App.User

    func authenticate(
        basic: BasicAuthorization,
        for request: Request
    ) -> EventLoopFuture<Void> {
        if basic.username == "test" && basic.password == "secret" {
            request.auth.login(User(name: "Vapor"))
        }
        return request.eventLoop.makeSucceededFuture(())
   }
}
```

如果你使用`async`/`await`，你可以使用`AsyncBasicAuthenticator`代替。

```swift
import Vapor

struct UserAuthenticator: AsyncBasicAuthenticator {
    typealias User = App.User

    func authenticate(
        basic: BasicAuthorization,
        for request: Request
    ) async throws {
        if basic.username == "test" && basic.password == "secret" {
            request.auth.login(User(name: "Vapor"))
        }
   }
}
```

这个协议要求你实现`authenticate(basic:for:)`，当传入的请求包含`Authorization: Basic... `头。一个包含用户名和密码的`BasicAuthorization`结构被传递给该方法。

在这个测试认证器中，用户名和密码与硬编码的值进行测试。在一个真正的认证器中，你可能会针对数据库或外部API进行检查。这就是为什么`authenticate`方法允许你返回一个未来。

!!! Tip
    密码不应该以明文形式存储在数据库中。总是使用密码哈希值进行比较。

如果认证参数是正确的，在这种情况下与硬编码的值相匹配，一个名为Vapor的`用户`被登录。如果认证参数不匹配，没有用户被登录，这表示认证失败。

如果你把这个认证器添加到你的应用程序中，并测试上面定义的路由，你应该看到名字`"Vapor"`返回成功的登录。如果凭证不正确, 你应该看到一个`401 Unauthorized`的错误.

## Bearer

Bearer认证在`Authorization`头中发送一个令牌。该令牌的前缀是`"Bearer"`。下面的请求示例发送了令牌`foo`。

```http
GET /me HTTP/1.1
Authorization: Bearer foo
``` 

Bearer认证通常用于API端点的认证。用户通常通过向登录端点发送用户名和密码等凭证来请求一个承载器令牌。这个令牌可能持续几分钟或几天，取决于应用程序的需求。

只要令牌是有效的，用户就可以用它来代替他或她的凭证，对API进行认证。如果令牌失效了，可以使用登录端点生成一个新的令牌。

要在你的应用程序中实现Bearer认证，创建一个符合`BearerAuthenticator`的新认证器。下面是一个硬编码的认证器例子，用来验证上面的请求。

```swift
import Vapor

struct UserAuthenticator: BearerAuthenticator {
    typealias User = App.User

    func authenticate(
        bearer: BearerAuthorization,
        for request: Request
    ) -> EventLoopFuture<Void> {
       if bearer.token == "foo" {
           request.auth.login(User(name: "Vapor"))
       }
       return request.eventLoop.makeSucceededFuture(())
   }
}
```

如果你使用`async`/`await`，你可以使用`AsyncBasicAuthenticator`代替:

```swift
import Vapor

struct UserAuthenticator: AsyncBearerAuthenticator {
    typealias User = App.User

    func authenticate(
        bearer: BearerAuthorization,
        for request: Request
    ) async throws {
       if bearer.token == "foo" {
           request.auth.login(User(name: "Vapor"))
       }
   }
}
```

这个协议要求你实现`authenticate(bearer:for:)`，当一个传入的请求包含`Authorization: Bearer ... `头时，将被调用。一个包含令牌的`BearerAuthorization`结构被传递给该方法。

在这个测试认证器中，令牌是针对一个硬编码的值进行测试。在真正的认证器中，你可以通过检查数据库或使用加密措施来验证令牌，就像JWT那样。这就是为什么`authenticate`方法允许你返回一个未来。

!!! Tip
    在实现令牌验证时，考虑横向可扩展性是很重要的。如果你的应用程序需要同时处理许多用户，验证可能是一个潜在的瓶颈。考虑你的设计如何在你的应用程序同时运行的多个实例中扩展。

如果认证参数是正确的，在这种情况下与硬编码的值相匹配，一个名为Vapor的`User`被登录。如果认证参数不匹配，则没有用户被登录，这表示认证失败。

如果你把这个认证器添加到你的应用程序中，并测试上面定义的路由，你应该看到名字`"Vapor"`返回成功登录。如果凭证不正确，你应该看到一个`401 Unauthorized`的错误。

## 组成

多个认证器可以组成(组合在一起)以创建更复杂的终端认证。由于认证器中间件在认证失败时不会拒绝请求，因此可以将多个这样的中间件串联起来。认证器可以通过两种主要方式组成。

### 组成方法


第一种认证组成方法是为同一用户类型链上一个以上的认证器。以下面的例子为例。

```swift
app.grouped(UserPasswordAuthenticator())
    .grouped(UserTokenAuthenticator())
    .grouped(User.guardMiddleware())
    .post("login") 
{ req in
    let user = try req.auth.require(User.self)
    // 对用户做一些事情。
}
```

这个例子假设有两个认证器`UserPasswordAuthenticator`和`UserTokenAuthenticator`，它们都认证`User`。这两个认证器都被添加到路由组中。最后，`GuardMiddleware`被添加到认证器之后，以要求`User`被成功认证。

这种认证器的组合产生了一个可以通过密码或令牌访问的路由。这样的路由可以允许用户登录并生成一个令牌，然后继续使用该令牌来生成新的令牌。

### 组成用户

认证组合的第二种方法是为不同的用户类型连锁认证器。以下面的例子为例：

```swift
app.grouped(AdminAuthenticator())
    .grouped(UserAuthenticator())
    .get("secure") 
{ req in
    guard req.auth.has(Admin.self) || req.auth.has(User.self) else {
        throw Abort(.unauthorized)
    }
    // 做点什么。
}
```

这个例子假设有两个认证器`AdminAuthenticator`和`UserAuthenticator`，分别认证`Admin`和`User`。这两个认证器都被添加到路由组中。不使用`GuardMiddleware`，而是在路由处理程序中添加一个检查，看`Admin`或`User`是否已被认证。如果没有，则抛出一个错误。

这种认证器的组合导致一个路由可以被两种不同类型的用户以潜在的不同认证方法访问。这样的路由可以允许正常的用户认证，同时仍然允许超级用户访问。

## 手动

你也可以使用`req.auth`手动处理认证。这对测试特别有用。

要手动登录一个用户，使用`req.auth.login(_:)`。任何`Authenticatable`的用户都可以被传递给这个方法。

```swift
req.auth.login(User(name: "Vapor"))
```

要获得认证的用户，使用`req.auth.require(_:)`。

```swift
let user: User = try req.auth.require(User.self)
print(user.name) // String
```

如果你不想在认证失败时自动抛出一个错误，你也可以使用`req.auth.get(_:)`。

```swift
let user = req.auth.get(User.self)
print(user?.name) // String?
```

要取消一个用户的认证，把用户类型传给`req.auth.logout(_:)`。

```swift
req.auth.logout(User.self)
```

## Fluent

[Fluent](fluent/overview.md)定义了两个协议`ModelAuthenticatable`和`ModelTokenAuthenticatable`，可以添加到你现有的模型中。使你的模型符合这些协议允许创建保护端点的认证器。

`ModelTokenAuthenticatable`用Bearer token进行认证。这是你用来保护大多数端点的方法。`ModelAuthenticatable`使用用户名和密码进行认证，由一个端点用于生成令牌。

本指南假设你熟悉Fluent，并且已经成功地配置了你的应用程序来使用数据库。如果你是Fluent的新手，请从[概述](fluent/overview.md)开始。

###用户

首先，你需要一个代表将被验证的用户的模型。在本指南中，我们将使用以下模型，但你也可以自由使用现有的模型。

```swift
import Fluent
import Vapor

final class User: Model, Content {
    static let schema = "users"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Field(key: "email")
    var email: String

    @Field(key: "password_hash")
    var passwordHash: String

    init() { }

    init(id: UUID? = nil, name: String, email: String, passwordHash: String) {
        self.id = id
        self.name = name
        self.email = email
        self.passwordHash = passwordHash
    }
}
```

该模型必须能够存储一个用户名，在这里是一个电子邮件，以及一个密码哈希值。我们还将`email`设置为唯一的字段，以避免重复的用户。这个例子模型的相应迁移在这里：

```swift
import Fluent
import Vapor

extension User {
    struct Migration: AsyncMigration {
        var name: String { "CreateUser" }

        func prepare(on database: Database) async throws {
            try await database.schema("users")
                .id()
                .field("name", .string, .required)
                .field("email", .string, .required)
                .field("password_hash", .string, .required)
                .unique(on: "email")
                .create()
        }

        func revert(on database: Database) async throws {
            try await database.schema("users").delete()
        }
    }
}
```

不要忘记将迁移添加到`app.migrations`中。

```swift
app.migrations.add(User.Migration())
``` 

你首先需要的是一个创建新用户的端点。让我们使用`POST /users`。创建一个[Content](content.md)结构，代表这个端点所期望的数据。

```swift
import Vapor

extension User {
    struct Create: Content {
        var name: String
        var email: String
        var password: String
        var confirmPassword: String
    }
}
```

如果你愿意，你可以将这个结构与[Validatable](validation.md)相符合，以增加验证要求。

```swift
import Vapor

extension User.Create: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("name", as: String.self, is: !.empty)
        validations.add("email", as: String.self, is: .email)
        validations.add("password", as: String.self, is: .count(8...))
    }
}
```

现在你可以创建`POST /users`端点。

```swift
app.post("users") { req async throws -> User in
    try User.Create.validate(content: req)
    let create = try req.content.decode(User.Create.self)
    guard create.password == create.confirmPassword else {
        throw Abort(.badRequest, reason: "Passwords did not match")
    }
    let user = try User(
        name: create.name,
        email: create.email,
        passwordHash: Bcrypt.hash(create.password)
    )
    try await user.save(on: req.db)
    return user
}
```

这个端点验证传入的请求，对`User.Create`结构进行解码，并检查密码是否匹配。然后，它使用解码后的数据创建一个新的`User`并将其保存到数据库。在保存到数据库之前，使用`Bcrypt`对明文密码进行散列。

建立并运行该项目，确保首先迁移数据库，然后使用下面的请求创建一个新的用户。

```http
POST /users HTTP/1.1
Content-Length: 97
Content-Type: application/json

{
    "name": "Vapor",
    "email": "test@vapor.codes",
    "password": "secret42",
    "confirmPassword": "secret42"
}
```

#### Model Authenticatable

现在你有了一个用户模型和一个创建新用户的端点，让我们把这个模型变成`ModelAuthenticatable`。这将允许该模型使用用户名和密码进行认证。

```swift
import Fluent
import Vapor

extension User: ModelAuthenticatable {
    static let usernameKey = \User.$email
    static let passwordHashKey = \User.$passwordHash

    func verify(password: String) throws -> Bool {
        try Bcrypt.verify(password, created: self.passwordHash)
    }
}
```

这个扩展为`User`增加了`ModelAuthenticatable`的一致性。前两个属性分别指定了哪些字段应该用来存储用户名和密码哈希值。`\`符号创建了一个通往字段的关键路径，Fluent可以用它来访问这些字段。

最后一个要求是验证Basic认证头中发送的明文密码的方法。由于我们在注册时使用Bcrypt对密码进行散列，我们将使用Bcrypt来验证所提供的密码是否与存储的密码散列相符。

现在`User`符合`ModelAuthenticatable`，我们可以创建一个认证器来保护登录路线。

```swift
let passwordProtected = app.grouped(User.authenticator())
passwordProtected.post("login") { req -> User in
    try req.auth.require(User.self)
}
```

`ModelAuthenticatable`增加了一个静态方法`authenticator`用于创建一个认证器。

通过发送以下请求来测试这个路由是否工作。

```http
POST /login HTTP/1.1
Authorization: Basic dGVzdEB2YXBvci5jb2RlczpzZWNyZXQ0Mg==
```

这个请求通过基本认证头传递用户名`test@vapor.codes`和密码`secret42`。你应该看到先前创建的用户被返回。

虽然理论上你可以使用Basic认证来保护你所有的端点，但建议使用单独的令牌来代替。这可以尽量减少你必须在互联网上发送用户敏感密码的频率。这也使得认证速度大大加快，因为你只需要在登录时进行密码散列。

### 用户令牌

创建一个新的模型来代表用户令牌。

```swift
import Fluent
import Vapor

final class UserToken: Model, Content {
    static let schema = "user_tokens"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "value")
    var value: String

    @Parent(key: "user_id")
    var user: User

    init() { }

    init(id: UUID? = nil, value: String, userID: User.IDValue) {
        self.id = id
        self.value = value
        self.$user.id = userID
    }
}
```

这个模型必须有一个`value`字段，用于存储令牌的唯一字符串。它还必须有一个[parent-relation](fluent/overview.md#parent)到用户模型。你可以在你认为合适的时候为这个令牌添加额外的属性，比如说过期日期。

接下来，为这个模型创建一个迁移。

```swift
import Fluent

extension UserToken {
    struct Migration: AsyncMigration {
        var name: String { "CreateUserToken" }
        
        func prepare(on database: Database) async throws {
            try await database.schema("user_tokens")
                .id()
                .field("value", .string, .required)
                .field("user_id", .uuid, .required, .references("users", "id"))
                .unique(on: "value")
                .create()
        }

        func revert(on database: Database) async throws {
            try await database.schema("user_tokens").delete()
        }
    }
}
```

请注意，这个迁移使得`value`字段是唯一的。它还在`user_id`字段和用户表之间创建了一个外键引用。

不要忘记把这个迁移添加到`app.migrations`中。

```swift
app.migrations.add(UserToken.Migration())
``` 

最后，在`User`上添加一个方法，用于生成一个新的令牌。这个方法将在登录时使用。

```swift
extension User {
    func generateToken() throws -> UserToken {
        try .init(
            value: [UInt8].random(count: 16).base64, 
            userID: self.requireID()
        )
    }
}
```

这里我们使用`[UInt8].random(count:)`来生成一个随机的token值。在这个例子中，使用了16个字节，或128位的随机数据。你可以根据你的需要调整这个数字。然后，随机数据被base-64编码，以使其易于在HTTP头文件中传输。

现在你可以生成用户令牌了，更新`POST /login`路由以创建并返回一个令牌。

```swift
let passwordProtected = app.grouped(User.authenticator())
passwordProtected.post("login") { req async throws -> UserToken in
    let user = try req.auth.require(User.self)
    let token = try user.generateToken()
    try await token.save(on: req.db)
    return token
}
```

通过使用上述相同的登录请求来测试这个路由是否有效。你现在应该在登录时得到一个令牌，看起来像这样。

```
8gtg300Jwdhc/Ffw784EXA==
```

请保管好你得到的令牌，因为我们很快就会用到它。

#### 可验证的Token模型

使`UserToken`符合`ModelTokenAuthenticatable`。这将允许令牌认证你的`User`模型。

```swift
import Vapor
import Fluent

extension UserToken: ModelTokenAuthenticatable {
    static let valueKey = \UserToken.$value
    static let userKey = \UserToken.$user

    var isValid: Bool {
        true
    }
}
```

第一个协议要求规定了哪个字段存储令牌的唯一值。这是将在承载认证头中发送的值。第二个要求是指定与`User` 模型的父关系。这是Fluent查找认证用户的方式。

最后一个要求是一个`isValid`布尔值。如果是`false`，则令牌将被从数据库中删除，用户将不会被认证。为了简单起见，我们将通过硬编码使令牌变成永恒的`true'。

现在令牌符合`ModelTokenAuthenticatable`，你可以创建一个认证器来保护路由。

创建一个新的端点`GET /me`来获取当前认证的用户。

```swift
let tokenProtected = app.grouped(UserToken.authenticator())
tokenProtected.get("me") { req -> User in
    try req.auth.require(User.self)
}
```

与`User`类似，`UserToken`现在有一个静态的`authenticator()`方法，可以生成一个认证器。认证器将尝试使用Bearer认证头中提供的值找到一个匹配的`UserToken`。如果它找到一个匹配的，它将获取相关的`User`并对其进行认证。

通过发送以下HTTP请求来测试这个路由是否有效，其中令牌是你在`POST /login`请求中保存的值。

```http
GET /me HTTP/1.1
Authorization: Bearer <token>
```

你应该看到认证的`User`返回。

## Session

Vapor的[Session API](session.md)可以用来在不同的请求之间自动保持用户认证。这通过在成功登录后在请求的会话数据中存储用户的唯一标识符来实现。在随后的请求中，用户的标识符被从会话中获取，并在调用你的路由处理程序之前用于验证用户。

会话非常适合在Vapor中构建的前端Web应用，它直接向Web浏览器提供HTML。对于API，我们建议使用无状态的、基于令牌的认证，以在请求之间保持用户数据。

### 会话可认证

要使用基于会话的认证，你将需要一个符合`SessionAuthenticatable`的类型。对于这个例子，我们将使用一个简单的结构。

```swift
import Vapor

struct User {
    var email: String
}
```

为了符合`SessionAuthenticatable`，你需要指定一个`sessionID`。这是将被存储在会话数据中的值，必须唯一地识别用户。

```swift
extension User: SessionAuthenticatable {
    var sessionID: String {
        self.email
    }
}
```

对于我们简单的`User`类型，我们将使用电子邮件地址作为唯一的会话标识符。

### 会话认证器

接下来，我们需要一个`SessionAuthenticator`来处理从持久化的会话标识符中解析用户的实例。


```swift
struct UserSessionAuthenticator: SessionAuthenticator {
    typealias User = App.User
    func authenticate(sessionID: String, for request: Request) -> EventLoopFuture<Void> {
        let user = User(email: sessionID)
        request.auth.login(user)
        return request.eventLoop.makeSucceededFuture(())
    }
}
```

如果你使用`async`/`await`，你可以使用`AsyncSessionAuthenticator`：

```swift
struct UserSessionAuthenticator: AsyncSessionAuthenticator {
    typealias User = App.User
    func authenticate(sessionID: String, for request: Request) async throws {
        let user = User(email: sessionID)
        request.auth.login(user)
    }
}
```

由于我们需要初始化我们的例子`User`的所有信息都包含在会话标识符中，我们可以同步创建和登录用户。在现实世界的应用中，你可能会使用会话标识符来执行数据库查询或API请求，以便在验证之前获取其余的用户数据。

接下来，让我们创建一个简单的承载认证器来执行初始认证。

```swift
struct UserBearerAuthenticator: AsyncBearerAuthenticator {
    func authenticate(bearer: BearerAuthorization, for request: Request) async throws {
        if bearer.token == "test" {
            let user = User(email: "hello@vapor.codes")
            request.auth.login(user)
        }
    }
}
```

当发送不记名令牌`test`时，这个认证器将用电子邮件`hello@vapor.codes`来认证用户。

最后，让我们在你的应用程序中把所有这些部分结合起来。

```swift
// 创建受保护的路由组，需要用户授权。
let protected = app.routes.grouped([
    app.sessions.middleware,
    UserSessionAuthenticator(),
    UserBearerAuthenticator(),
    User.guardMiddleware(),
])

// 添加GET /me路由，用于读取用户的电子邮件。
protected.get("me") { req -> String in
    try req.auth.require(User.self).email
}
```

`SessionsMiddleware`首先被添加到应用程序上，以启用会话支持。关于配置会话的更多信息可以在[会话API](session.md)部分找到。

接下来，添加`SessionAuthenticator`。如果会话处于活动状态，这将处理对用户的认证。

如果认证还没有被保存在会话中，请求将被转发到下一个认证器。`UserBearerAuthenticator`将检查承载令牌，如果它等于`"test"`，将对用户进行认证。

最后，`User.guardMiddleware()`将确保`User`已经被之前的一个中间件认证过。如果用户没有被认证，将抛出一个错误。

要测试这个路由，首先发送以下请求：

```http
GET /me HTTP/1.1
authorization: Bearer test
```

这将导致`UserBearerAuthenticator`对用户进行认证。一旦通过认证，`UserSessionAuthenticator`将在会话存储中保留用户的标识符，并生成一个cookie。在第二次请求路由时使用响应中的cookie。

```http
GET /me HTTP/1.1
cookie: vapor_session=123
```

这一次，`UserSessionAuthenticator`将对用户进行认证，你应该再次看到用户的电子邮件返回。

### 模型会话可认证

Fluent模型可以通过符合`ModelSessionAuthenticatable`来生成`SessionAuthenticator`。这将使用模型的唯一标识符作为会话标识符，并自动执行数据库查询以从会话中恢复模型。

```swift
import Fluent

final class User: Model { ... }

// 允许这个模型在会话中被持久化。
extension User: ModelSessionAuthenticatable { }
```

你可以把`ModelSessionAuthenticatable`作为一个空的一致性添加到任何现有的模型中。一旦添加，一个新的静态方法将可用于为该模型创建一个`SessionAuthenticator'。

```swift
User.sessionAuthenticator()
```

这将使用应用程序的默认数据库来解决用户的问题。要指定一个数据库，请传递标识符。

```swift
User.sessionAuthenticator(.sqlite)
```

## 网站认证

网站是认证的一个特殊情况，因为使用浏览器限制了你如何将凭证附加到浏览器上。这就导致了两种不同的认证方案。

* 通过一个表格进行初始登录
* 使用会话cookie验证的后续调用

Vapor和Fluent提供了几个助手来实现这种无缝连接。

### 会话认证

会话认证的工作原理如上所述。你需要将会话中间件和会话认证器应用于用户将要访问的所有路由。这包括任何受保护的路由，任何公开的路由，但如果用户登录了，你可能仍然想访问他们（例如显示一个账户按钮）***和***登录路由。

你可以在你的应用程序中的**configure.swift**中全局启用这个功能，就像这样。

```swift
app.middleware.use(app.sessions.middleware)
app.middleware.use(User.sessionAuthenticator())
```

这些中间件做了以下工作。

* 会话中间件接收请求中提供的会话cookie，并将其转换为一个会话。
* 会话验证器获取会话，并查看该会话是否有一个经过验证的用户。如果有，中间件就对请求进行认证。在响应中，会话认证器查看该请求是否有一个已认证的用户，并将其保存在会话中，以便在下一个请求中对其进行认证。

###保护路由

在保护API的路由时，如果请求没有被认证，你通常会返回一个状态代码为**401 Unauthorized**的HTTP响应。然而，对于使用浏览器的人来说，这并不是一个很好的用户体验。Vapor为任何`Authenticatable`类型提供了一个 `RedirectMiddleware`，以便在这种情况下使用：

```swift
let protectedRoutes = app.grouped(User.redirectMiddleware(path: "/login?loginRequired=true"))
```

这与`GuardMiddleware`的工作原理类似。任何对注册到`protectedRoutes`的路由的请求，如果没有经过验证，将被重定向到提供的路径。这允许你告诉你的用户登录，而不是仅仅提供一个**401未经授权的**。

### 表格登录

为了验证用户和未来的请求与会话，你需要将用户登录。Vapor提供了一个`ModelCredentialsAuthenticatable`协议，以符合该协议。这可以处理通过表单登录的问题。首先让你的`User`符合这个协议。

```swift
extension User: ModelCredentialsAuthenticatable {
    static let usernameKey = \User.$email
    static let passwordHashKey = \User.$password

    func verify(password: String) throws -> Bool {
        try Bcrypt.verify(password, created: self.password)
    }
}
```

这和`ModelAuthenticatable`是一样的，如果你已经符合这个要求，那么你就不需要再做什么了。接下来将这个`ModelCredentialsAuthenticator`中间件应用到你的登录表单POST请求：

```swift
let credentialsProtectedRoute = sessionRoutes.grouped(User.credentialsAuthenticator())
credentialsProtectedRoute.post("login", use: loginPostHandler)
```

这使用默认的凭证认证器来保护登录路线。你必须在POST请求中发送`username`和`password`。你可以像这样设置你的表单：

```html
 <form method="POST" action="/login">
    <label for="username">Username</label>
    <input type="text" id="username" placeholder="Username" name="username" autocomplete="username" required autofocus>
    <label for="password">Password</label>
    <input type="password" id="password" placeholder="Password" name="password" autocomplete="current-password" required>
    <input type="submit" value="Sign In">    
</form>
```

`CredentialsAuthenticator`从请求体中提取`username`和`password`，从用户名中找到用户并验证密码。如果密码是有效的，中间件就对请求进行认证。然后`SessionAuthenticator`为后续请求验证会话。

## JWT

[JWT](jwt.md)提供了一个`JWTAuthenticator`，可用于验证传入请求中的JSON Web令牌。如果你是JWT的新手，请查看[概述](jwt.md)。

首先，创建一个代表JWT有效载荷的类型。

```swift
// JWT有效载荷示例。
struct SessionToken: Content, Authenticatable, JWTPayload {

    // 常量
    let expirationTime = 60 * 15
    
    // Token数据
    var expiration: ExpirationClaim
    var userId: UUID
    
    init(userId: UUID) {
        self.userId = userId
        self.expiration = ExpirationClaim(value: Date().addingTimeInterval(expirationTime))
    }
    
    init(user: User) throws {
        self.userId = try user.requireID()
        self.expiration = ExpirationClaim(value: Date().addingTimeInterval(expirationTime))
    }

    func verify(using signer: JWTSigner) throws {
        try expiration.verifyNotExpired()
    }
}
```

接下来，我们可以定义一个成功的登录响应中所包含的数据表示。目前，该响应将只有一个属性，即代表签名的JWT的字符串。

```swift
struct ClientTokenReponse: Content {
    var token: String
}
```

使用我们的JWT令牌和响应的模型，我们可以使用一个密码保护的登录路线，它返回一个`ClientTokenReponse`，并包括一个签名的`SessionToken`。

```swift
let passwordProtected = app.grouped(User.authenticator(), User.guardMiddleware())
passwordProtected.post("login") { req -> ClientTokenReponse in
    let user = try req.auth.require(User.self)
    let payload = try SessionToken(with: user)
    return ClientTokenReponse(token: try req.jwt.sign(payload))
}
```

另外，如果你不想使用认证器，你可以有一些看起来像以下的东西。
```swift
app.post("login") { req -> ClientTokenReponse in
    // Validate provided credential for user
    // Get userId for provided user
    let payload = try SessionToken(userId: userId)
    return ClientTokenReponse(token: try req.jwt.sign(payload))
}
```

通过使有效载荷符合`Authenticatable`和`JWTPayload`，你可以使用`authenticator()`方法生成一个路由认证器。将其添加到路由组中，在你的路由被调用之前自动获取并验证JWT。

```swift
// Create a route group that requires the SessionToken JWT.
let secure = app.grouped(SessionToken.authenticator(), SessionToken.guardMiddleware())
```

添加可选的[防护中间件](#guard-middleware)将要求授权成功。

在受保护的路由内部，你可以使用`req.auth`访问经过认证的JWT有效载荷。

```swift
// Return ok reponse if the user-provided token is valid.
secure.post("validateLoggedInUser") { req -> HTTPStatus in
    let sessionToken = try req.auth.require(SessionToken.self)
    print(sessionToken.userId)
    return .ok
}
```
