# JWT


JSON Web Token（JWT）是一个开放的标准（[RFC 7519](https://tools.ietf.org/html/rfc7519)），它定义了一种紧凑和独立的方式，以JSON对象的形式在各方之间安全地传输信息。这种信息可以被验证和信任，因为它是经过数字签名的。JWTs可以使用秘密（使用HMAC算法）或使用RSA或ECDSA的公共/私人密钥对进行签名。

## 开始使用

使用JWT的第一步是在你的[Package.swift](spm.md#package-manifest)中添加依赖关系。

```swift
// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "my-app",
    dependencies: [
         // 其他的依赖性...
        .package(url: "https://github.com/vapor/jwt.git", from: "4.0.0"),
    ],
    targets: [
        .target(name: "App", dependencies: [
         // 其他的依赖性...
            .product(name: "JWT", package: "jwt")
        ]),
        // 其他目标...
    ]
)
```

如果您在Xcode中直接编辑清单，它将会自动接收更改并在保存文件时获取新的依赖关系。否则，运行`swift package resolve`来获取新的依赖关系。

### 配置

JWT模块为`Application`添加了一个新属性`jwt`，用于配置。为了签署或验证JWT，你需要添加一个签名者。最简单的签名算法是`HS256`或HMAC与SHA-256。

```swift
import JWT

// 添加带有SHA-256签名者的HMAC。
app.jwt.signers.use(.hs256(key: "secret"))
```

`HS256`签名器需要一个密钥来初始化。与其他签名器不同的是，这个单一的密钥既可用于签名_也可用于验证令牌。了解更多关于以下可用的[算法](#algorithms)。

### 有效载荷

让我们试着验证一下下面这个JWT的例子。

```swift
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ2YXBvciIsImV4cCI6NjQwOTIyMTEyMDAsImFkbWluIjp0cnVlfQ.lS5lpwfRNSZDvpGQk6x5JI1g40gkYCOWqbc3J_ghowo
```

你可以通过访问[jwt.io](https://jwt.io)并在调试器中粘贴该令牌来检查该令牌的内容。将 "验证签名 "部分的键设置为`secret`。

我们需要创建一个符合`JWTPayload`的结构，代表JWT的结构。我们将使用JWT包含的[claims](#claims)来处理常见的字段，如`sub`和`exp`。

```swift
// JWT有效载荷结构。
struct TestPayload: JWTPayload {
    // 将较长的 Swift 属性名称映射为
    // JWT 有效载荷中使用的缩短的键。
    enum CodingKeys: String, CodingKey {
        case subject = "sub"
        case expiration = "exp"
        case isAdmin = "admin"
    }

    // "sub"(subject)声明确定了作为JWT主体的委托人。
    // JWT的主体。
    var subject: SubjectClaim

    // "exp" (expiration time) 声称确定了JWT的过期时间。
    // 或之后，该JWT必须不被接受进行处理。
    var expiration: ExpirationClaim

    // 自定义数据。
    // 如果为真，该用户是管理员。
    var isAdmin: Bool

    // 运行除签名验证之外的任何其他验证逻辑。
    // 在这里进行签名验证。
    // 由于我们有一个ExpirationClaim，我们将
    // 调用其验证方法。
    func verify(using signer: JWTSigner) throws {
        try self.expiration.verifyNotExpired()
    }
}
```

###验证

现在我们有了一个`JWTPayload`，我们可以将上面的JWT附加到一个请求中，并使用`req.jwt`来获取和验证它。在你的项目中添加以下路由。

```swift
// 从传入的请求中获取并验证JWT。
app.get("me") { req -> HTTPStatus in
    let payload = try req.jwt.verify(as: TestPayload.self)
    print(payload)
    return .ok
}
```

`req.jwt.verify`帮助器将检查`Authorization`头是否有承载令牌。如果存在，它将解析JWT并验证其签名和声明。如果这些步骤失败，将抛出一个401 Unauthorized错误。

通过发送以下HTTP请求来测试该路由。

```http
GET /me HTTP/1.1
authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ2YXBvciIsImV4cCI6NjQwOTIyMTEyMDAsImFkbWluIjp0cnVlfQ.lS5lpwfRNSZDvpGQk6x5JI1g40gkYCOWqbc3J_ghowo
```

如果一切正常，将返回一个200 OK响应，并打印出有效载荷：

```swift
TestPayload(
    subject: "vapor", 
    expiration: 4001-01-01 00:00:00 +0000, 
    isAdmin: true
)
```

### 签名

这个包也可以生成JWTs，也被称为签名。为了证明这一点，让我们使用上一节中的`TestPayload`。在你的项目中添加以下路由。

```swift
// 生成并返回一个新的JWT。
app.post("login") { req -> [String: String] in
    // 创建一个新的JWTPayload的实例
    let payload = TestPayload(
        subject: "vapor",
        expiration: .init(value: .distantFuture),
        isAdmin: true
    )
    // 返回已签名的JWT
    return try [
        "token": req.jwt.sign(payload)
    ]
}
```

`req.jwt.sign`助手将使用默认配置的签名器对`JWTPayload`进行序列化和签名。编码后的JWT将以`String`形式返回。

通过发送以下HTTP请求来测试该路由。

```http
POST /login HTTP/1.1
```

你应该看到新生成的令牌在一个_200 OK_的响应中返回。

```json
{
   "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ2YXBvciIsImV4cCI6NjQwOTIyMTEyMDAsImFkbWluIjp0cnVlfQ.lS5lpwfRNSZDvpGQk6x5JI1g40gkYCOWqbc3J_ghowo"
}
```

##认证

关于使用Vapor认证API的JWT的更多信息，请访问[Authentication &rarr; JWT](authentication.md#jwt)。

## 算法

Vapor的JWT API支持使用以下算法验证和签署令牌。

### HMAC

HMAC是最简单的JWT签名算法。它使用一个单一的密钥，可以同时签署和验证令牌。该密钥可以是任何长度。

- `hs256`: 使用SHA-256的 HMAC
- `hs384`: 使用SHA-384的HMAC
- `hs512`: 使用SHA-512的HMAC

```swift
// 添加带有SHA-256签名者的HMAC。
app.jwt.signers.use(.hs256(key: "secret"))
```

### RSA

RSA是最常用的JWT签名算法。它支持不同的公钥和私钥。这意味着公钥可以被分发，用于验证JWT的真实性，而生成它们的私钥是保密的。

要创建一个RSA签名器，首先要初始化一个`RSAKey`。这可以通过传入组件来完成。

```swift
// 用组件初始化一个RSA密钥。
let key = RSAKey(
    modulus: "...",
    exponent: "...",
    // 只包括在私人钥匙中。
    privateExponent: "..."
)
```

你也可以选择加载一个PEM文件：

```swift
let rsaPublicKey = """
-----BEGIN PUBLIC KEY-----
MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQC0cOtPjzABybjzm3fCg1aCYwnx
PmjXpbCkecAWLj/CcDWEcuTZkYDiSG0zgglbbbhcV0vJQDWSv60tnlA3cjSYutAv
7FPo5Cq8FkvrdDzeacwRSxYuIq1LtYnd6I30qNaNthntjvbqyMmBulJ1mzLI+Xg/
aX4rbSL49Z3dAQn8vQIDAQAB
-----END PUBLIC KEY-----
"""

// 用公共pem初始化一个RSA密钥。
let key = RSAKey.public(pem: rsaPublicKey)
```

使用`.private`来加载私人RSA PEM密钥。这些钥匙的开头是：

```
-----BEGIN RSA PRIVATE KEY-----
```

一旦你有了RSAKey，你可以用它来创建一个RSA签名器。

- `rs256`：使用SHA-256的RSA
- `rs384`：使用SHA-384的RSA
- `rs512`：使用SHA-512的RSA

```swift
// 添加带有SHA-256的RSA签名者。
try app.jwt.signers.use(.rs256(key: .public(pem: rsaPublicKey)))
```

### ECDSA

ECDSA是一种更现代的算法，与RSA相似。在给定的密钥长度下，它被认为比RSA[^1]更安全。然而，在决定之前，你应该做你自己的研究。

[^1]: [https://sectigostore.com/blog/ecdsa-vs-rsa-everything-you-need-to-know/](https://sectigostore.com/blog/ecdsa-vs-rsa-everything-you-need-to-know/)

像RSA一样，你可以使用PEM文件加载ECDSA密钥：

```swift
let ecdsaPublicKey = """
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE2adMrdG7aUfZH57aeKFFM01dPnkx
C18ScRb4Z6poMBgJtYlVtd9ly63URv57ZW0Ncs1LiZB7WATb3svu+1c7HQ==
-----END PUBLIC KEY-----
"""

// 用公共PEM初始化ECDSA密钥。
let key = ECDSAKey.public(pem: ecdsaPublicKey)
```

使用`.private`来加载ECDSA PEM私钥。这些钥匙的开头是：

```
-----BEGIN PRIVATE KEY-----
```

你也可以使用`generate()`方法生成随机ECDSA。这对测试是很有用的。

```swift
let key = try ECDSAKey.generate()
```

一旦你有了ECDSA密钥，你就可以用它来创建ECDSA签名器。

- `es256`：使用SHA-256的ECDSA
- `es384`：使用SHA-384的ECDSA
- `es512`：使用SHA-512的ECDSA

```swift
// 添加带有SHA-256的ECDSA签名者。
try app.jwt.signers.use(.es256(key: .public(pem: ecdsaPublicKey)))
```

### 关键识别符(kid)

如果你使用多种算法，你可以使用密钥标识符（`kid`s）来区分它们。当配置一个算法时，传递`kid`参数。

```swift
// 添加带有SHA-256签名者的HMAC，命名为 "a"。
app.jwt.signers.use(.hs256(key: "foo"), kid: "a")
// 添加带有SHA-256签名者的HMAC，命名为 "b"。
app.jwt.signers.use(.hs256(key: "bar"), kid: "b")
```

签署JWTs时，要为所需的签名者传递`kid`参数。

```swift
// 使用签名者"a"签名
req.jwt.sign(payload, kid: "a")
```

这将自动在JWT头的`"kid"`字段中包括签名者的名字。当验证JWT时，这个字段将被用来查找适当的签名者。

```swift
// 使用"kid"头指定的签名者进行验证。
// 如果没有"kid"头，将使用默认签名人。
let payload = try req.jwt.verify(as: TestPayload.self)
```

由于[JWKs](#jwk)已经包含了`kid`值，你不需要在配置时指定它们。

```swift
// JWKs已经包含了 "孩子 "字段。
let jwk: JWK = ...
app.jwt.signers.use(jwk: jwk)
```

## Claims

Vapor的JWT包包括几个帮助器，用于实现常见的[JWT声明](https://tools.ietf.org/html/rfc7519#section-4.1)。

|索赔|类型|验证方法|
|---|---|---|
|`aud`|`AudienceClaim`|`verifyIntendedAudience(includes:)`|
|`exp`|`ExpirationClaim`|`verifyNotExpired(currentDate:)`|
|`jti`|`IDClaim`|n/a|
|`iat`|`IssuedAtClaim`|n/a|
|`iss`|`IssuerClaim`|n/a|
|`locale`|`LocaleClaim`|n/a|
|`nbf`|`NotBeforeClaim`|`verifyNotBefore(currentDate:)`|
|`sub`|`SubjectClaim`|n/a|

所有的索赔应该在`JWTPayload.verify`方法中进行验证。如果索赔有一个特殊的验证方法，你可以使用该方法。否则，使用`value`访问索赔的值并检查它是否有效。

## JWK

JSON网络密钥(JWK)是一种JavaScript对象符号(JSON)数据结构，代表一个加密密钥([RFC7517](https://tools.ietf.org/html/rfc7517))。这些通常用于为客户提供验证JWT的密钥。

例如，苹果公司将他们的Sign in with Apple JWKS托管在以下网址。

```http
GET https://appleid.apple.com/auth/keys
```

你可以把这个JSON网络密钥集（JWKS）添加到你的`JWTSigners`中。

```swift
import JWT
import Vapor

// 下载JWKS。
// 如果需要，这可以异步完成。
let jwksData = try Data(
    contentsOf: URL(string: "https://appleid.apple.com/auth/keys")!
)

// 对下载的JSON进行解码。
let jwks = try JSONDecoder().decode(JWKS.self, from: jwksData)

// 创建签名者并添加JWKS。
try app.jwt.signers.use(jwks: jwks)
```

你现在可以将JWTs从Apple传递到`verify`方法。JWT头中的密钥标识符（`kid`）将被用来自动选择正确的密钥进行验证。

截至目前，JWK只支持RSA密钥。此外，JWT发行者可能会轮换他们的JWKS，意味着你需要偶尔重新下载。请参阅Vapor支持的JWT [Vendors](#vendors)列表，了解能自动做到这一点的API。

## 供应商

Vapor提供API来处理以下流行的发行商的JWTs。

### 苹果

首先，配置你的苹果应用标识符。

```swift
// 配置苹果应用程序的标识符。
app.jwt.apple.applicationIdentifier = "..."
```

然后，使用`req.jwt.apple`助手来获取和验证苹果JWT。

```swift
//从授权头中获取并验证苹果JWT。
app.get("apple") { req -> EventLoopFuture<HTTPStatus> in
    req.jwt.apple.verify().map { token in
        print(token) // AppleIdentityToken
        return .ok
    }
}

// 或

app.get("apple") { req async throws -> HTTPStatus in
    let token = try await req.jwt.apple.verify()
    print(token) // AppleIdentityToken
    return .ok
}
```

### 谷歌

首先，配置你的谷歌应用标识符和G套件域名。

```swift
// 配置谷歌应用程序标识符和域名。
app.jwt.google.applicationIdentifier = "..."
app.jwt.google.gSuiteDomainName = "..."
```

然后，使用`req.jwt.google`帮助器来获取和验证Google JWT。

```swift
// 从授权头中获取并验证Google JWT。
app.get("google") { req -> EventLoopFuture<HTTPStatus> in
    req.jwt.google.verify().map { token in
        print(token) // GoogleIdentityToken
        return .ok
    }
}

// 或

app.get("google") { req async throws -> HTTPStatus in
    let token = try await req.jwt.google.verify()
    print(token) // GoogleIdentityToken
    return .ok
}
```

### Microsoft

首先，配置你的Microsoft应用程序标识符。

```swift
// 配置微软应用程序标识符。
app.jwt.microsoft.applicationIdentifier = "..."
```

然后，使用`req.jwt.microsoft`帮助器来获取和验证Microsoft的JWT。

```swift
//从授权头中获取并验证微软JWT。
app.get("microsoft") { req -> EventLoopFuture<HTTPStatus> in
    req.jwt.microsoft.verify().map { token in
        print(token) // MicrosoftIdentityToken
        return .ok
    }
}

// 或

app.get("microsoft") { req async throws -> HTTPStatus in
    let token = try await req.jwt.microsoft.verify()
    print(token) // MicrosoftIdentityToken
    return .ok
}
```
