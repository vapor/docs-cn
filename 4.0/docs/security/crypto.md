# 加密

Vapor包括[SwiftCrypto](https://github.com/apple/swift-crypto/)，它是苹果公司CryptoKit库的一个Linux兼容的移植。一些额外的加密 API 被暴露出来，以满足 SwiftCrypto 还没有的东西，比如 [Bcrypt](https://en.wikipedia.org/wiki/Bcrypt) 和 [TOTP](https://en.wikipedia.org/wiki/Time-based_One-time_Password_algorithm)。

## SwiftCrypto

Swift的`Crypto`库实现了苹果的CryptoKit API。因此，[CryptoKit 文档](https://developer.apple.com/documentation/cryptokit) 和[WWDC 讲座](https://developer.apple.com/videos/play/wwdc2019/709) 是学习该 API 的绝佳资源。

当你导入Vapor时，这些API将自动可用。

```swift
import Vapor

let digest = SHA256.hash(data: Data("hello".utf8))
print(digest)
```

CryptoKit包括对以下内容的支持。

- 加密：`SHA512`, `SHA384`, `SHA256`。
- 消息验证码：`HMAC`。
- 密码器：`AES`, `ChaChaPoly`.
- 公钥加密：`Curve25519`, `P521`, `P384`, `P256`。
- 不安全的散列：`SHA1`, `MD5`。

## Bcrypt

Bcrypt是一种密码散列算法，使用随机的盐来确保多次散列同一密码不会产生相同的摘要。

Vapor提供了一个`Bcrypt`类型，用于散列和比较密码。

```swift
import Vapor

let digest = try Bcrypt.hash("test")
```

因为Bcrypt使用盐，所以密码哈希值不能直接比较。明文密码和现有摘要都必须一起验证。

```swift
import Vapor

let pass = try Bcrypt.verify("test", created: digest)
if pass {
    // 密码和摘要相符。
} else {
    // 错误的密码。
}
```

使用Bcrypt密码登录可以通过首先从数据库中通过电子邮件或用户名获取用户的密码摘要来实现。然后可以根据提供的明文密码对已知的摘要进行验证。

## OTP

Vapor支持HOTP和TOTP两种一次性密码。OTP与SHA-1、SHA-256和SHA-512哈希函数一起工作，可以提供6、7或8位数的输出。OTP通过生成一个一次性的人类可读密码来提供认证。要做到这一点，各方首先要商定一个对称密钥，该密钥必须始终保持私有，以维护所生成密码的安全。

#### HOTP

HOTP是一种基于HMAC签名的OTP。除了对称密钥外，双方还商定了一个计数器，它是一个为密码提供唯一性的数字。在每次生成尝试后，计数器都会增加。
```swift
let key = SymmetricKey(size: .bits128)
let hotp = HOTP(key: key, digest: .sha256, digits: .six)
let code = hotp.generate(counter: 25)

// 或者使用静态生成函数
HOTP.generate(key: key, digest: .sha256, digits: .six, counter: 25)
```

#### TOTP

TOTP是HOTP的一个基于时间的变体。它的工作原理基本相同，但不是一个简单的计数器，而是用当前时间来产生唯一性。为了补偿由不同步的时钟、网络延迟、用户延迟和其他干扰因素带来的不可避免的偏差，生成的TOTP代码在指定的时间间隔内（最常见的是30秒）保持有效。
```swift
let key = SymmetricKey(size: .bits128)
let totp = TOTP(key: key, digest: .sha256, digits: .six, interval: 60)
let code = totp.generate(time: Date())

// 或者使用静态生成函数
TOTP.generate(key: key, digest: .sha256, digits: .six, interval: 60, time: Date())
```

#### 范围
OTP对于提供验证和不同步计数器的回旋余地非常有用。这两种OTP实现都有能力生成一个有误差范围的OTP。
```swift
let key = SymmetricKey(size: .bits128)
let hotp = HOTP(key: key, digest: .sha256, digits: .six)

// 生成一个正确计数器的窗口
let codes = hotp.generate(counter: 25, range: 2)
```
上面的例子允许留有2的余地，这意味着HOTP将对计数器的值`23 ... 27`进行计算，并且所有这些代码都将被返回。

!!! warning
    注意：使用的误差幅度越大，攻击者的行动时间和自由度就越大，降低了算法的安全性。
