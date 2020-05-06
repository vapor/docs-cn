# 路由

路由是为传入请求找到合适的请求处理程序的过程。Vapor 路由的核心是基于 [RoutingKit](https://github.com/vapor/routing-kit) 的高性能三节点路由器。

## 概述 

要了解路由在 Vapor 中的工作方式，你首先应该了解有关 HTTP 请求的一些基础知识。
看一下以下示例请求：

```http
GET /hello/vapor HTTP/1.1
host: vapor.codes
content-length: 0
```

这是对 URL `/hello/vapor` 的一个简单的 HTTP 请求。 如果你将其指向以下 URL，则浏览器将发出这样的 HTTP 请求：

```
http://vapor.codes/hello/vapor
```

### HTTP 方法

请求的第一部分是 HTTP 方法。其中 GET 是最常见的 HTTP 方法，以下这些是经常会使用几种方法，这些 HTTP 方法通常与 [CRUD](https://en.wikipedia.org/wiki/Create,_read,_update_and_delete) 语义相关联。


|method|crud|
|:--|:--|
|`GET`|Read|
|`POST`|Create|
|`PUT`|Replace|
|`PATCH`|Update|
|`DELETE`|Delete|


### 请求路径

在 HTTP 方法之后是请求的 URI。它由以 `/` 开头的路径和在 `?` 之后的可选查询字符串组成。HTTP 方法和路径是 Vapor 用于路由请求的方法。

URI 之后是 HTTP 版本，后跟零个或多个标头，最后是正文。由于这是一个 `GET` 请求，因此没有主体(body)。


### 路由方法

让我们看一下如何在 Vapor 中处理此请求。

```swift
app.get("hello", "vapor") { req in 
    return "Hello, vapor!"
}
```


所有常见的 HTTP 方法都可以作为 `Application` 的方法使用。它们接受一个或多个字符串参数，这些字符串参数表示请求路径，以 `/` 分隔。

请注意，你也可以在方法之后使用 `on` 编写此代码。


```swift
app.on(.GET, "hello", "vapor") { ... }
```

注册此路由后，上面的示例 HTTP 请求将导致以下 HTTP 响应。

```http
HTTP/1.1 200 OK
content-length: 13
content-type: text/plain; charset=utf-8

Hello, vapor!
```

### 路由参数

现在，我们已经成功地基于 HTTP 方法和路径路由了请求，让我们尝试使路径动态化。注意，名称 “vapor” 在路径和响应中都是硬编码的。让我们对它进行动态化，以便你可以访问 `/hello/<any name>` 并获得响应。


```swift
app.get("hello", ":name") { req -> String in
    let name = req.parameters.get("name")!
    return "Hello, \(name)!"
}
```

通过使用前缀为 `:` 的路径组件，我们向路由器指示这是动态组件。现在，此处提供的任何字符串都将与此路由匹配。 然后，我们可以使用 `req.parameters` 访问字符串的值。

如果再次运行示例请求，你仍然会收到一条响应，向 vapor 打招呼。 但是，你现在可以在  `/hello/` 之后添加任何名称，并在响应中看到它。 让我们尝试 `/hello/swift`。


```http
GET /hello/swift HTTP/1.1
content-length: 0
```
```http
HTTP/1.1 200 OK
content-length: 13
content-type: text/plain; charset=utf-8

Hello, swift!
```

现在你已经了解了基础知识，请查看每个部分以了解有关参数，分组等的更多信息。

## 路径

路由为给定的 HTTP 方法和 URI 路径指定请求处理程序。它还可以存储其他元数据。

### 方法

可以使用多种 HTTP 方法帮助程序将路由直接注册到你的 `Application` 。

```swift
// responds to GET /foo/bar/baz
app.get("foo", "bar", "baz") { req in
	...
}
```

路由处理程序支持返回 `ResponseEncodable` 的任何内容。这包括 `Content` 和将来值为 `ResponseEncodable` 的 `EventLoopFuture`。

你可以在 `in` 之前使用 `-> T` 来指定路线的返回类型。这在编译器无法确定返回类型的情况下很有用。

```swift
app.get("foo") { req -> String in
	return "bar"
}
```

这些是受支持的路由器方法：

- `get`
- `post`
- `patch`
- `put`
- `delete`

除了 HTTP 方法协助程序外，还有一个 `on` 函数可以接受 HTTP 方法作为输入参数。

```swift
// responds to OPTIONS /foo/bar/baz
app.on(.OPTIONS, "foo", "bar", "baz") { req in
	...
}
```

### 路径组件

每种路由注册方法都接受 `PathComponent` 的可变列表。此类型可以用字符串文字表示，并且有四种情况：


- Constant (`foo`)
- Parameter (`:foo`)
- Anything (`:`)
- Catchall (`*`)

#### 静态路径

这是静态路由组件。仅允许在此位置具有完全匹配的字符串的请求。

```swift
// responds to GET /foo/bar/baz
app.get("foo", "bar", "baz") { req in
	...
}
```

#### 参数路径

这是一个动态路由组件。此位置的任何字符串都将被允许。参数路径组件以 `:` 前缀指定。 `:` 后面的字符串将用作参数名称。你可以使用该名称稍后从请求中获取参数值。

```swift
// responds to GET /foo/bar/baz
// responds to GET /foo/qux/baz
// ...
app.get("foo", ":bar", "baz") { req in
	...
}
```

#### 过滤路径

这与参数方式非常相似，只是该值被丢弃了。此路径组件仅指定为  `:` 。

```swift
// responds to GET /foo/bar/baz
// responds to GET /foo/qux/baz
// ...
app.get("foo", ":", "baz") { req in
	...
}
```

#### 通配路径

这是与一个或多个组件匹配的动态路由组件，仅使用 `*` 指定。请
求中将允许此位置或更高位置的任何字符串。

```swift
// responds to GET /foo/bar
// responds to GET /foo/bar/baz
// ...
app.get("foo", "*") { req in 
    ...
}
```

### 参数

使用参数路径组件（以 `:` 前缀）时，该位置的 URI 值将存储在 `req.parameters` 中。 你可以使用路径组件的名称来访问。


```swift
// responds to GET /hello/foo
// responds to GET /hello/bar
// ...
app.get("hello", ":name") { req -> String in
    let name = req.parameters.get("name")!
    return "Hello, \(name)!"
}
```

!!! 提示
    我们可以确定 `req.parameters.get` 在这里绝不会返回 `nil` ，因为我们的路径包含 `:name`。 但是，如果要访问中间件中的路由参数或由多个路由触发的代码中的路由参数，则需要处理 `nil` 的可能性。

`req.parameters` 还支持将参数自动转换为 `LosslessStringConvertible` 类型。


```swift
// responds to GET /hello/42
// responds to GET /hello/1337
// ...
app.get("number", ":x") { req -> String in 
	guard let int = req.parameters.get("x", as: Int.self) else {
		throw Abort(.badRequest)
	}
	return "\(int) is a great number"
}
```

### 数据流

使用 `on` 方法注册路由时，你可以指定如何处理请求主体。默认情况下，请求主体在调用处理程序之前被收集到内存中。 这是有效的，因为它允许请求内容解码同步。 但是，对于上传文件等大型请求，这可能会占用你的系统内存。

要更改请求正文的处理方式，请在注册路由时使用 `body` 参数。有两种方法：

- `collect`: 内存中处理请求体
- `stream`: 使用 `stream` 数据流

```swift
app.on(.POST, "file-upload", body: .stream) { req in
    ...
}
```

当请求体使用数据流传输时， `req.body.data` 将为 `nil`。你必须使用 `req.body.drain` 来处理每个发送到路由的数据块。

### 查看路由

你可以通过提供的 `Routes` 服务或使用 `app.routes` 来访问应用程序的路径。

```swift
print(app.routes.all) // [Route]
```

Vapor 还附带了一个 `routes` 命令，该命令以 ASCII 格式的表格打印所有可用的路由。

```sh
$ swift run Run routes
+--------+----------------+
| GET    | /              |
+--------+----------------+
| GET    | /hello/        |
+--------+----------------+
| GET    | /todos         |
+--------+----------------+
| POST   | /todos         |
+--------+----------------+
| DELETE | /todos/:todoID |
+--------+----------------+
```

### Metadata

所有路线注册方法都会返回创建的 `Route`。 这使你可以将元数据添加到路由的 `userInfo` 字典中。有一些默认方法可用，例如添加描述。


```swift
app.get("hello", ":name") { req in
	...
}.description("says hello")
```

## 路由组

通过路由分组，你可以创建带有路径前缀或特定中间件的一组路由。分组支持基于构建器和闭包的语法。

所有分组方法都返回一个 `RouteBuilder` ，这意味着你可以将组与其他路由构建方法无限地混合、匹配和嵌套。

### 路径前缀

路径前缀路由组允许你在一个路由组之前添加一个或多个路径组件。

```swift
let users = app.grouped("users")
// GET /users
users.get { req in
    ...
}
// POST /users
users.post { req in
    ...
}
// GET /users/:id
users.get(":id") { req in
    let id = req.parameters.get("id")!
    ...
}
```

你可以传递给诸如 `get` 或 `post` 这样的方法的任何路径成分都可以传递给 `grouped`。 还有另一种基于闭包的语法。

```swift
app.group("users") { users in
    // GET /users
    users.get { req in
        ...
    }
    // POST /users
    users.post { req in
        ...
    }
    // GET /users/:id
    users.get(":id") { req in
        let id = req.parameters.get("id")!
        ...
    }
}
```

嵌套路径前缀路由组使你可以简洁地定义 CRUD API。

```swift
app.group("users") { users in
    // GET /users
    users.get { ... }
    // POST /users
    users.post { ... }

    users.group(":id") { user in
        // GET /users/:id
        user.get { ... }
        // PATCH /users/:id
        user.patch { ... }
        // PUT /users/:id
        user.put { ... }
    }
}
```

### 中间件

除了为路径组件添加前缀之外，你还可以将中间件添加到路由组。

```swift
app.get("fast-thing") { req in
    ...
}
app.group(RateLimitMiddleware(requestsPerMinute: 5)) { rateLimited in
    rateLimited.get("slow-thing") { req in
        ...
    }
}
```

这对于使用不同的身份验证中间件保护路由的子集特别有用。

```swift
app.post("login") { ... }
let auth = app.grouped(AuthMiddleware())
auth.get("dashboard") { ... }
auth.get("logout") { ... }
```
