# Fluent

Fluent是Swift的一个[ORM](https://en.wikipedia.org/wiki/Object-relational_mapping)框架。它利用Swift强大的类型系统，为你的数据库提供一个易于使用的接口。使用Fluent的核心是创建模型类型，代表你数据库中的数据结构。这些模型然后被用来执行创建、读取、更新和删除操作，而不是编写原始查询。

## 配置

当使用`vapor new`创建一个项目时，回答"YES"包括Fluent并选择你想使用的数据库驱动。这将自动为你的新项目添加依赖项，以及配置代码的例子。

### 现有项目

如果你有一个现有的项目想加入Fluent，你需要在你的[package](../start/spm.md)中添加两个依赖项。

- [vapor/fluent](https://github.com/vapor/fluent)@4.0.0
- 你选择的一个（或多个）Fluent驱动程序

```swift
.package(url: "https://github.com/vapor/fluent.git", from: "4.0.0"),
.package(url: "https://github.com/vapor/fluent-<db>-driver.git", from: <version>),
```

```swift
.target(name: "App", dependencies: [
    .product(name: "Fluent", package: "fluent"),
    .product(name: "Fluent<db>Driver", package: "fluent-<db>-driver"),
    .product(name: "Vapor", package: "vapor"),
]),
```

一旦软件包被添加为依赖项，你可以使用`configure.swift`中的`app.databases`来配置你的数据库。

```swift
import Fluent
import Fluent<db>Driver

app.databases.use(<db config>, as: <identifier>)
```

以下每个Fluent驱动程序都有更具体的配置说明。

### 驱动程序

Fluent目前有四个官方支持的驱动程序。你可以在GitHub上搜索标签[`fluent-driver`](https://github.com/topics/fluent-driver)，以获得官方和第三方Fluent数据库驱动的完整列表。

#### PostgreSQL

PostgreSQL是一个开源的、符合标准的SQL数据库。它很容易在大多数云主机供应商上配置。这是Fluent公司**推荐的**数据库驱动。

要使用PostgreSQL，请在你的软件包中添加以下依赖项。

```swift
.package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.0.0")
```

```swift
.product(name: "FluentPostgresDriver", package: "fluent-postgres-driver")
```

一旦添加了依赖关系，使用`configure.swift`中的`app.databases.use`将数据库的凭证配置给Fluent。

```swift
import Fluent
import FluentPostgresDriver

app.databases.use(.postgres(hostname: "localhost", username: "vapor", password: "vapor", database: "vapor"), as: .psql)
```

你也可以从数据库连接字符串中解析凭证。

```swift
try app.databases.use(.postgres(url: "<connection string>"), as: .psql)
```

#### SQLite

SQLite是一个开源的、嵌入式的SQL数据库。它的简单性使它成为原型设计和测试的最佳选择。

要使用SQLite，请在你的软件包中添加以下依赖项。

```swift
.package(url: "https://github.com/vapor/fluent-sqlite-driver.git", from: "4.0.0")
```

```swift
.product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver")
```

一旦添加了依赖关系，使用`configure.swift`中的`app.databases.use`来配置Fluent的数据库。

```swift
import Fluent
import FluentSQLiteDriver

app.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite)
```

你也可以配置SQLite在内存中短暂地存储数据库。

```swift
app.databases.use(.sqlite(.memory), as: .sqlite)
```

如果你使用的是内存数据库，请确保使用`--auto-migrate`将Fluent设置为自动迁移，或者在添加迁移后运行`app.autoMigrate()`。

```swift
app.migrations.add(CreateTodo())
try app.autoMigrate().wait()
// 或
try await app.autoMigrate()
```

!!!提示
    SQLite配置会自动对所有创建的连接启用外键约束，但不会改变数据库本身的外键配置。直接删除数据库中的记录，可能会违反外键约束和触发器。

#### MySQL

MySQL是一个流行的开源SQL数据库。它在许多云主机供应商上都可以使用。这个驱动也支持MariaDB。

要使用MySQL，请在你的软件包中添加以下依赖项。

```swift
.package(url: "https://github.com/vapor/fluent-mysql-driver.git", from: "4.0.0-beta")
```

```swift
.product(name: "FluentMySQLDriver", package: "fluent-mysql-driver")
```

一旦添加了依赖关系，使用`configure.swift`中的`app.databases.use`将数据库的凭证配置给Fluent。

```swift
import Fluent
import FluentMySQLDriver

app.databases.use(.mysql(hostname: "localhost", username: "vapor", password: "vapor", database: "vapor"), as: .mysql)
```

你也可以从数据库连接字符串中解析凭证。

```swift
try app.databases.use(.mysql(url: "<connection string>"), as: .mysql)
```

要配置一个不涉及SSL证书的本地连接，你应该禁用证书验证。例如，如果在Docker中连接到MySQL 8数据库，你可能需要这样做。

```swift
var tls = TLSConfiguration.makeClientConfiguration()
tls.certificateVerification = .none
    
app.databases.use(.mysql(
    hostname: "localhost",
    username: "vapor",
    password: "vapor",
    database: "vapor",
    tlsConfiguration: tls
), as: .mysql)
```

!!! warning
    请不要在生产中禁用证书验证。你应该向`TLSConfiguration`提供一个证书来验证。

#### MongoDB

MongoDB是一个流行的无模式NoSQL数据库，为程序员设计。该驱动支持所有的云主机供应商和3.4以上版本的自我托管安装。

!!!注意
    该驱动由社区创建和维护的MongoDB客户端提供支持，该客户端名为[MongoKitten](https://github.com/OpenKitten/MongoKitten)。MongoDB维护着一个官方客户端，[mongo-swift-driver](https://github.com/mongodb/mongo-swift-driver)，以及一个Vapor集成，[mongodb-vapor](https://github.com/mongodb/mongodb-vapor)。

要使用MongoDB，请在你的软件包中添加以下依赖项。

```swift
.package(url: "https://github.com/vapor/fluent-mongo-driver.git", from: "1.0.0"),
```

```swift
.product(name: "FluentMongoDriver", package: "fluent-mongo-driver")
```

一旦添加了依赖关系，使用`configure.swift`中的`app.databases.use`将数据库的凭证配置给Fluent。

要进行连接，请传递一个标准的MongoDB[连接URI格式](https://docs.mongodb.com/master/reference/connection-string/index.html)的连接字符串。

```swift
import Fluent
import FluentMongoDriver

try app.databases.use(.mongo(connectionString: "<connection string>"), as: .mongo)
```

## 模型

模型代表你数据库中的固定数据结构，像表或集合。模型有一个或多个字段来存储可编码的值。所有的模型也有一个唯一的标识符。属性包装器被用来表示标识符和字段，以及后面提到的更复杂的映射关系。看看下面的模型，它表示一个星系。

```swift
final class Galaxy: Model {
    // 表或集合的名称。
    static let schema = "galaxies"

    // 这个Galaxy的唯一标识符。
    @ID(key: .id)
    var id: UUID?

    // 银河系的名字。
    @Field(key: "name")
    var name: String

    // 创建一个新的、空的Galaxy。
    init() { }

    // 创建一个新的Galaxy，并设置所有属性。
    init(id: UUID? = nil, name: String) {
        self.id = id
        self.name = name
    }
}
```

要创建一个新的模型，创建一个符合`Model`的新类。

!!!提示
    建议将模型类标记为`final`，以提高性能并简化一致性要求。

`Model`协议的第一个要求是静态字符串`schema`。

```swift
static let schema = "galaxies"
```

这个属性告诉Fluent这个模型对应于哪个表或集合。这可以是一个已经存在于数据库中的表，也可以是一个你将通过[迁移](#migrations)创建的表。该模式通常是`snake_case`和复数。

### 标识符

下一个要求是一个名为`id'的标识符字段。

```swift
@ID(key: .id)
var id: UUID?
```

这个字段必须使用`@ID`属性包装器。Fluent推荐使用`UUID`和特殊的`.id`字段键，因为这与Fluent的所有驱动兼容。

如果你想使用一个自定义的ID键或类型，请使用[`@ID(custom:)`](model.md#custom-identifier) 重载。

### 字段

在标识符被添加后，你可以添加任何你想要的字段来存储额外信息。在这个例子中，唯一的附加字段是星系的名字。

```swift
@Field(key: "name")
var name: String
```

对于简单的字段，使用`@Field`属性包装器。和`@ID`一样，`key`参数指定了数据库中字段的名称。这对于数据库字段命名规则可能与Swift中不同的情况特别有用，例如使用`snake_case`而不是`camelCase`。

接下来，所有模型都需要一个空的init。这允许Fluent创建模型的新实例。

```swift
init() { }
```

最后，你可以为你的模型添加一个方便的init，设置其所有的属性。

```swift
init(id: UUID? = nil, name: String) {
    self.id = id
    self.name = name
}
```

如果你向你的模型添加新的属性，使用方便的inits特别有帮助，因为如果init方法改变了，你会得到编译时错误。

## 迁移

如果你的数据库使用预定义的模式，如SQL数据库，你将需要一个迁移来为你的模型准备数据库。迁移对于用数据播种数据库也很有用。要创建一个迁移，需要定义一个符合`Migration`或`AsyncMigration`协议的新类型。请看下面的迁移，它适用于之前定义的 "Galaxy "模型。

```swift
struct CreateGalaxy: AsyncMigration {
    // 准备数据库以存储Galaxy模型。
    func prepare(on database: Database) async throws {
        try await database.schema("galaxies")
            .id()
            .field("name", .string)
            .create()
    }

    // 可选择恢复prepare方法中的修改。
    func revert(on database: Database) async throws {
        try await database.schema("galaxies").delete()
    }
}
```

`prepare`方法用于准备数据库以存储`Galaxy`模型。

### 模式

在这个方法中，`database.schema(_:)`被用来创建一个新的`SchemaBuilder`。在调用`create()`创建模式之前，一个或多个`字段'被添加到创建器中。

每个添加到构建器的字段都有一个名称、类型和可选的约束。

```swift
field(<name>, <type>, <optional constraints>)
```

有一个方便的`id()`方法可以使用Fluent推荐的默认值添加`@ID`属性。

恢复迁移会撤销在prepare方法中做出的任何改变。在这种情况下，这意味着删除Galaxy的模式。

一旦定义了迁移，你必须把它加入到`configure.swift`中的`app.migrations`中，以此来告诉Fluent。

```swift
app.migrations.add(CreateGalaxy())
```

### 迁移

要运行迁移，可以在命令行中调用`vapor run migrate`或者在Xcode的Run scheme中添加`migrate`作为参数。


```
$ vapor run migrate
Migrate Command: Prepare
The following migration(s) will be prepared:
+ CreateGalaxy on default
Would you like to continue?
y/n> y
Migration successful
```

## 查询

现在，你已经成功地创建了一个模型并迁移了你的数据库，你已经准备好进行你的第一次查询。

###所有

看看下面的路线，它将返回数据库中所有星系的一个数组。

```swift
app.get("galaxies") { req async throws in
    try await Galaxy.query(on: req.db).all()
}
```

为了在路由闭合中直接返回一个Galaxy，请在`内容'中添加一致性。

```swift
final class Galaxy: Model, Content {
    ...
}
```

`Galaxy.query`是用来为模型创建一个新的查询构建器。`req.db`是对你应用程序的默认数据库的引用。最后，`all()`返回存储在数据库中的所有模型。

如果你编译并运行项目，请求`GET /galaxies`，你应该看到返回一个空数组。让我们添加一个创建新星系的路由。

### 创建


按照RESTful惯例，使用`POST /galaxies`端点来创建一个新星系。由于模型是可编码的，你可以直接从请求体中解码一个星系。

```swift
app.post("galaxies") { req -> EventLoopFuture<Galaxy> in
    let galaxy = try req.content.decode(Galaxy.self)
    return galaxy.create(on: req.db)
        .map { galaxy }
}
```

!!! 另见
    参见 [Content &rarr; Overview](../basics/content.md) 了解更多关于解码请求体的信息。

一旦你有了模型的实例，调用`create(on:)`将模型保存到数据库中。这将返回一个`EventLoopFuture<Void>`，这表明保存已经完成。一旦保存完成，使用`map`返回新创建的模型。

如果你使用`async`/`await`，你可以这样写你的代码。

```swift
app.post("galaxies") { req async throws -> Galaxy in
    let galaxy = try req.content.decode(Galaxy.self)
    try await galaxy.create(on: req.db)
    return galaxy
}
```

在这种情况下，异步版本不会返回任何东西，但一旦保存完成就会返回。

建立并运行该项目，并发送以下请求。

```http
POST /galaxies HTTP/1.1
content-length: 21
content-type: application/json

{
    "name": "Milky Way"
}
```

你应该得到创建的模型和一个标识符作为响应。

```json
{
    "id": ...,
    "name": "Milky Way"
}
```

现在，如果你再次查询`GET /galaxies`，你应该看到新创建的星系在数组中返回。


## 关联

没有恒星的星系是什么呢？让我们通过在`Galaxy`和一个新的`Star`模型之间添加一对多的关系，来快速了解一下Fluent强大的关系功能。

```swift
final class Star: Model, Content {
    // 表或集合的名称。
    static let schema = "stars"

    // 该星的唯一标识符。
    @ID(key: .id)
    var id: UUID?

    // "明星"的名字。
    @Field(key: "name")
    var name: String

    // 参考这颗星所处的星系。
    @Parent(key: "galaxy_id")
    var galaxy: Galaxy

    // 创建一个新的、空的Star。
    init() { }

    // 创建一个新的星，并设置所有的属性。
    init(id: UUID? = nil, name: String, galaxyID: UUID) {
        self.id = id
        self.name = name
        self.$galaxy.id = galaxyID
    }
}
```

### 父级

新的`Star`模型与`Galaxy`非常相似，但有一个新的字段类型。`@Parent`.

```swift
@Parent(key: "galaxy_id")
var galaxy: Galaxy
```

父级属性是一个存储另一个模型的标识符的字段。持有引用的模型被称为"child"，被引用的模型被称为"parent"。这种类型的关系也被称为 "一对多"。该属性的`key`参数指定了在数据库中用于存储父代键的字段名。

在init方法中，使用`$galaxy`来设置父标识符。

```swift
self.$galaxy.id = galaxyID
```

 通过在父属性的名字前加上`$`，你可以访问底层的属性包装器。这是访问内部`@Field`的必要条件，它存储了实际的标识符值。

!!! 另见
    请查看 Swift Evolution 中关于属性包装器的建议，了解更多信息。[[SE-0258] Property Wrappers](https://github.com/apple/swift-evolution/blob/master/proposals/0258-property-wrappers.md)

接下来，创建一个迁移，为处理`Star`的数据库做准备。


```swift
struct CreateStar: AsyncMigration {
    // 为存储Star模型的数据库做准备。
    func prepare(on database: Database) async throws {
        try await database.schema("stars")
            .id()
            .field("name", .string)
            .field("galaxy_id", .uuid, .references("galaxies", "id"))
            .create()
    }

    // 可选择恢复prepare方法中的修改。
    func revert(on database: Database) async throws {
        try await database.schema("stars").delete()
    }
}
```

这与星系的迁移基本相同，只是多了一个字段来存储父级galaxy的标识符。

```swift
field("galaxy_id", .uuid, .references("galaxies", "id"))
```

这个字段指定了一个可选的约束条件，告诉数据库这个字段的值参考了"galaxies"模式中的字段 "id"。这也被称为外键，有助于确保数据的完整性。

一旦创建了迁移，就把它添加到`app.migrations`中，放在`CreateGalaxy`迁移之后。

```swift
app.migrations.add(CreateGalaxy())
app.migrations.add(CreateStar())
```

由于迁移是按顺序进行的，而且`CreateStar`引用的是星系模式，所以排序很重要。最后，[运行迁移](#migrate)来准备数据库。

添加一个用于创建新star的路由。

```swift
app.post("stars") { req async throws -> Star in
    let star = try req.content.decode(Star.self)
    try await star.create(on: req.db)
    return star
}
```

使用下面的HTTP请求创建一个新的star，引用之前创建的galaxy。

```http
POST /stars HTTP/1.1
content-length: 36
content-type: application/json

{
    "name": "Sun",
    "galaxy": {
        "id": ...
    }
}
```

你应该看到新创建的star有一个独特的标识符返回。

```json
{
    "id": ...,
    "name": "Sun",
    "galaxy": {
        "id": ...
    }
}
```

### 子级

现在让我们来看看如何利用Fluent的急于加载功能，在`GET /galaxies`路由中自动返回星系的星星。给`Galaxy`模型添加以下属性。

```swift
// 这个galaxy中的所有星星。
@Children(for: \.$galaxy)
var stars: [Star]
```

`@Children`属性包装器是`@Parent`的反面。它需要一个通往孩子的`@Parent`字段的关键路径作为`for`参数。它的值是一个子模型的数组，因为可能存在零个或多个子模型。不需要改变galaxy的迁移，因为这种关系所需的所有信息都存储在`Star`上。

### 急于加载

现在关系已经完成，你可以使用查询生成器上的`with`方法来自动获取并序列化galaxy-star关系。

```swift
app.get("galaxies") { req in
    try await Galaxy.query(on: req.db).with(\.$stars).all()
}
```

`@Children`关系的关键路径被传递给`with`，告诉Fluent在所有产生的模型中自动加载这个关系。建立并运行另一个请求，向`GET /galaxies`发送。现在你应该看到恒星自动包含在响应中。

```json
[
    {
        "id": ...,
        "name": "Milky Way",
        "stars": [
            {
                "id": ...,
                "name": "Sun",
                "galaxy": {
                    "id": ...
                }
            }
        ]
    }
]
```

## 接下来

恭喜你创建了你的第一个模型和迁移，并进行了基本的创建和读取操作。关于所有这些功能的更深入的信息，请查看Fluent指南中各自的章节。
