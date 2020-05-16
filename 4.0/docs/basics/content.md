# 内容

Vapor的 content API 允许您轻松地对HTTP消息进行编码/解码。默认使用[JSON](https://tools.ietf.org/html/rfc7159)编码，并支持[URL-Encoded Form](https://en.wikipedia.org/wiki/Percent-encoding#The_application/x-www-form-urlencoded_type)和[Multipart](https://tools.ietf.org/html/rfc2388)。该API也是可配置的，允许您为某些HTTP内容类型添加、修改或替换编码策略。

## 总览

要了解Vapor的 content API 是如何工作的，您应该先了解一些关于HTTP消息的基本知识。看看下面这个请求的示例。

```http
POST /greeting HTTP/1.1
content-type: application/json
content-length: 18

{"hello": "world"}
```

该请求表明，它包含使用`content-type`标头和`application/json`媒体类型的JSON编码数据。正如承诺的那样，一些JSON数据在正文中的标头之后。

### 内容结构

解码这个HTTP消息的第一步是创建一个与预期结构相匹配的Codable类型。

```swift
struct Greeting: Content {
    var hello: String
}
```

使类型符合`Content`，将自动增加与`Codable`的一致性，以及与content API 一起工作的附加实用程序。

一旦您有了Content结构，就可以使用`req.content`从传入的请求中解码。

```swift
app.post("greeting") { req in 
    let greeting = try req.content.decode(Greeting.self)
    print(greeting.hello) // "world"
    return HTTPStatus.ok
}
```

解码方法使用请求的content类型来寻找合适的解码器。如果没有找到解码器，或者请求中不包含content 类型标头，将抛出`415`错误。

这意味着该路由自动接受所有其他支持的内容类型，如url编码形式:

```http
POST /greeting HTTP/1.1
content-type: application/x-www-form-urlencoded
content-length: 11

hello=world
```

### 支持的媒体类型

以下是 content API 默认支持的媒体类型。

|name|header value|media type|
|-|-|-|
|JSON|application/json|`.json`|
|Multipart|multipart/form-data|`.formData`|
|URL-Encoded Form|application/x-www-form-urlencoded|`.urlEncodedForm`|
|Plaintext|text/plain|`.plainText`|
|HTML|text/html|`.html`|

不是所有的媒体类型都支持所有的Codable功能。例如，JSON不支持顶层片段，Plaintext不支持嵌套数据。

## 查询

Vapor的 Content API 支持处理URL查询字符串中的URL编码数据。

### 解码

要了解URL查询字符串的解码是如何工作的，请看下面的示例请求。

```http
GET /hello?name=Vapor HTTP/1.1
content-length: 0
```

就像处理HTTP消息正文内容的API一样，解析URL查询字符串的第一步是创建一个与预期结构相匹配的`struct`。

```swift
struct Hello: Content {
    var name: String?
}
```

注意，`name`是一个可选的`String`，因为URL查询字符串应该是可选的。如果您需要一个参数，请用路由参数代替。

现在，您已经为该路由的预期查询字符串提供了`Content`结构，可以对其进行解码了。

```swift
app.get("hello") { req -> String in 
    let hello = try req.query.decode(Hello.self)
    return "Hello, \(hello.name ?? "Anonymous")"
}
```

根据上面的示例请求，这条路线将产生以下响应:

```http
HTTP/1.1 200 OK
content-length: 12

Hello, Vapor
```

如果省略了查询字符串，就像下面的请求一样，将使用"匿名"来代替。

```http
GET /hello HTTP/1.1
content-length: 0
```

### 单值

除了对`Content`结构进行解码外，Vapor还支持使用下标从查询字符串中提取单个值。

```swift
let name: String? = req.query["name"]
```

## 钩子

Vapor会自动调用`Content`类型的`beforeDecode`和`afterDecode`。提供了默认的实现，但您可以使用这些方法来运行自定义逻辑。

```swift
// 在此内容被解码后运行。
func afterDecode() throws {
    // 名称可能没有传入，但如果传入了，那就不能是空字符串。
    self.name = self.name?.trimmingCharacters(in: .whitespacesAndNewlines)
    if let name = self.name, name.isEmpty {
        throw Abort(.badRequest, reason: "Name must not be empty.")
    }
}

// 在此内容被编码前运行。
func beforeEncode() throws {
    // 必须*总是*传递一个名称回来，它不能是一个空字符串。
    guard 
        let name = self.name?.trimmingCharacters(in: .whitespacesAndNewlines), 
        !name.isEmpty 
    else {
        throw Abort(.badRequest, reason: "Name must not be empty.")
    }
    self.name = name
}
```

## 覆盖默认值

可以配置Vapor的 Content API 所使用的默认编码器和解码器。

### 全局

`ContentConfiguration.global`允许您改变Vapor默认使用的编码器和解码器。这对于改变整个应用程序的数据解析和序列化方式非常有用。

```swift
// 创建一个新的JSON编码器，使用unix-timestamp日期编码
let encoder = JSONEncoder()
encoder.dateEncodingStrategy = .secondsSince1970

// 覆盖用于媒体类型".json "的全局编码器。
ContentConfiguration.global.use(encoder: encoder, for: .json)
```

更改`ContentConfiguration`通常在`configure.swift`中完成。

### 一次性

对编码和解码方法的调用，如`req.content.decode`，支持为一次性使用传递自定义编码器。

```swift
// 创建一个新的JSON解码器，使用unix-timestamp日期的时间戳
let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .secondsSince1970

// 使用自定义解码器对Hello结构进行解码
let hello = try req.content.decode(Hello.self, using: decoder)
```

## 定制编码器

应用程序和第三方软件包可以通过创建自定义编码器来增加对Vapor默认不支持的媒体类型的支持。

### 内容

Vapor为能够处理HTTP消息体中内容的编码器指定了两种协议。`ContentDecoder`和`ContentEncoder`。

```swift
public protocol ContentEncoder {
    func encode<E>(_ encodable: E, to body: inout ByteBuffer, headers: inout HTTPHeaders) throws
        where E: Encodable
}

public protocol ContentDecoder {
    func decode<D>(_ decodable: D.Type, from body: ByteBuffer, headers: HTTPHeaders) throws -> D
        where D: Decodable
}
```

遵循这些协议允许您的自定义编码器注册到上面指定的`ContentConfiguration`。

### URL 查询

Vapor为能够处理URL查询字符串中的内容的编码器指定了两个协议:`URLQueryDecoder`和`URLQueryEncoder`。

```swift
public protocol URLQueryDecoder {
    func decode<D>(_ decodable: D.Type, from url: URI) throws -> D
        where D: Decodable
}

public protocol URLQueryEncoder {
    func encode<E>(_ encodable: E, to url: inout URI) throws
        where E: Encodable
}
```

符合这些协议允许您的自定义编码器注册到`ContentConfiguration`中，使用`use(urlEncoder:)`和`use(urlDecoder:)`方法处理URL查询字符串。