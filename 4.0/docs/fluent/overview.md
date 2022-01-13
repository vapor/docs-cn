# Fluent概念

## Fluent

Fluent是Swift的一个[ORM](https://en.wikipedia.org/wiki/Object-relational_mapping)框架。它利用Swift强大的类型系统，为你的数据库提供一个易于使用的接口。使用Fluent的核心是创建模型类型，代表数据库中的数据结构。这些模型然后被用来执行创建、读取、更新和删除操作，而不是编写原始查询。

## 配置

当使用`vapor new`创建一个项目时，回答"是"包括Fluent并选择你想使用的数据库驱动。这将自动为你的新项目添加依赖项，以及配置代码的例子。

### 现有项目

如果你有一个现有的项目想加入Fluent，你需要在你的[package](notion://www.notion.so/cainluo/start/spm.md)中加入两个依赖项。

- [vapor/fluent](https://github.com/vapor/fluent)@4.0.0
- 你选择的一个（或多个）Fluent驱动程序

```swift
.package(url: "https://github.com/vapor/fluent.git", from: "4.0.0-beta"),
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

Fluent目前有三个官方支持的驱动程序。你可以在GitHub上搜索标签[`fluent-driver`](<https://github.com/topics/fluent-database>)，以获得官方和第三方Fluent数据库驱动的完整列表。

### PostgreSQL

PostgreSQL是一个开源的、符合标准的SQL数据库。它很容易在大多数云主机供应商上配置。这是Fluent公司**推荐的**数据库驱动。

要使用PostgreSQL，请在你的软件包中添加以下依赖项。

```swift
.package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.0.0-beta")
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

### SQLite

SQLite是一个开源的、嵌入式的SQL数据库。它的简单性质使它成为原型设计和测试的最佳选择。

要使用SQLite，请在你的软件包中添加以下依赖项。

```swift
.package(url: "https://github.com/vapor/fluent-sqlite-driver.git", from: "4.0.0-beta")
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

你也可以配置SQLite将数据库短暂地存储在内存中。

```swift
app.databases.use(.sqlite(.memory), as: .sqlite)
```

如果你使用的是内存数据库，请确保使用`--auto-migrate`将Fluent设置为自动迁移，或者在添加迁移后运行`app.autoMigrate()`。

```swift
app.migrations.add(CreateTodo())
try app.autoMigrate().wait()
```

### MySQL

MySQL是一个流行的开放源码SQL数据库。它在许多云主机供应商上都可以使用。这个驱动也支持MariaDB。

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

### MongoDB

MongoDB是一个流行的无模式NoSQL数据库，为程序员设计。该驱动支持所有云主机供应商和3.4及以上版本的自我托管安装。

要使用MongoDB，请在你的软件包中添加以下依赖项。

```swift
.package(url: "https://github.com/vapor/fluent-mongo-driver.git", from: "1.0.0"),
```

```swift
.product(name: "FluentMongoDriver", package: "fluent-mongo-driver")
```

一旦添加了依赖关系，使用`configure.swift`中的`app.databases.use`将数据库的凭证配置给Fluent。

要进行连接，请传递一个标准的MongoDB连接URI格式的[连接字符串](https://docs.mongodb.com/master/reference/connection-string/index.html)。

```swift
import Fluent
import FluentMongoDriver

try app.databases.use(.mongo(connectionString: "<connection string>"), as: .mongo)
```

## 模型

模型代表你数据库中的固定数据结构，像表或集合。模型有一个或多个字段来存储可编码的值。所有的模型也有一个唯一的标识符。属性包装器被用来表示标识符和字段，以及后面提到的更复杂的映射关系。看看下面的模型，它表示一个Galaxy。

```swift
final class Galaxy: Model {
    // Name of the table or collection.
    static let schema = "galaxies"

    // Unique identifier for this Galaxy.
    @ID(key: .id)
    var id: UUID?

    // The Galaxy's name.
    @Field(key: "name")
    var name: String

    // Creates a new, empty Galaxy.
    init() { }

    // Creates a new Galaxy with all properties set.
    init(id: UUID? = nil, name: String) {
        self.id = id
        self.name = name
    }
}
```

要创建一个新的模型，创建一个符合`Model`的新类。

!!!提示 

​	建议将模型类标记为`final`，以提高性能并简化一致性要求。

`Model`协议的第一个要求是静态字符串`schema`。

```swift
static let schema = "galaxies"
```

这个属性告诉Fluent这个模型对应于哪个表或集合。这可以是一个已经存在于数据库中的表，也可以是一个你将用[迁移](#迁移)创建的表。该模式通常是`snake_case`和复数。

### 标识符

下一个要求是一个名为`id`的标识符字段。

```swift
@ID(key: .id)
var id: UUID?
```

这个字段必须使用`@ID`属性包装器。Fluent推荐使用`UUID`和特殊的`.id`字段键，因为这与Fluent的所有驱动兼容。

如果你想使用一个自定义的ID键或类型，请使用`@ID(custom:)`重载。

### 字段

在标识符被添加之后，你可以添加你想要的任何字段来存储额外的信息。在这个例子中，唯一的附加字段是星系的名字。

```swift
@Field(key: "name")
var name: String
```

对于简单的字段，使用`@Field`属性包装器。和`@ID`一样，`key`参数指定了数据库中字段的名称。这对于数据库字段命名规则可能与Swift中不同的情况特别有用，例如使用`snake_case`而不是`camelCase`。

接下来，所有模型都需要一个空的init。这允许Fluent创建模型的新实例。

```swift
init() { }
```

最后，你可以为你的模型添加一个便捷的init，设置其所有的属性。

```swift
init(id: UUID? = nil, name: String) {
    self.id = id
    self.name = name
}
```

如果你向你的模型添加新的属性，使用便捷的inits特别有帮助，因为如果init方法改变了，你会得到编译时错误。

## 迁移

如果你的数据库使用预定义的模式，如SQL数据库，你将需要一个迁移来为你的模型准备数据库。迁移对于用数据播种数据库也很有用。要创建一个迁移，需要定义一个符合`Migration`协议的新类型。请看下面这个先前定义的`Galaxy`模型的迁移。

```swift
struct CreateGalaxy: Migration {
    // Prepares the database for storing Galaxy models.
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("galaxies")
            .id()
            .field("name", .string)
            .create()
    }

    // Optionally reverts the changes made in the prepare method.
    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("galaxies").delete()
    }
}
```

`prepare`方法用于准备数据库以存储`Galaxy`模型。

### 模式

在这个方法中，`database.schema(_:)`被用来创建一个新的`SchemaBuilder`。在调用`create()`创建模式之前，一个或多个`字段`被添加到创建器中。

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

### 所有

看看下面的路线，它将返回数据库中所有星系的一个数组。

```swift
app.get("galaxies") { req in
    Galaxy.query(on: req.db).all()
}
```

为了在路由闭包中直接返回一个Galaxy，请在`Content`中添加一致性。

```swift
final class Galaxy: Model, Content {
    ...
}
```

`Galaxy.query`是用来为模型创建一个新的查询构建器。`req.db`是对你应用程序的默认数据库的引用。最后，`all()`返回存储在数据库中的所有模型。

如果你编译并运行该项目并请求`GET /galaxies`，你应该看到返回一个空数组。让我们添加一个创建新星系的路由。

### 创建

按照RESTful惯例，使用`POST /galaxies`端点来创建一个新galaxy。由于模型是可编码的，你可以直接从请求体中解码一个星系。

```swift
app.post("galaxies") { req -> EventLoopFuture<Galaxy> in
    let galaxy = try req.content.decode(Galaxy.self)
    return galaxy.create(on: req.db)
        .map { galaxy }
}
```

!!!另见 

​	参见 [Content &rarr; Overview](notion://www.notion.so/basics/content.md) 以了解更多关于请求体解码的信息。

一旦你有了模型的实例，调用`create(on:)`将模型保存到数据库中。这将返回一个`EventLoopFuture<Void>`，这表明保存已经完成。一旦保存完成，使用`map`返回新创建的模型。

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

## 关系

没有恒星的星系是什么呢？让我们通过在 "星系 "和一个新的 "星星 "模型之间添加一对多的关系，来快速了解一下Fluent强大的关系功能。

```swift
final class Star: Model, Content {
    // Name of the table or collection.
    static let schema = "stars"

    // Unique identifier for this Star.
    @ID(key: .id)
    var id: UUID?

    // The Star's name.
    @Field(key: "name")
    var name: String

    // Reference to the Galaxy this Star is in.
    @Parent(key: "galaxy_id")
    var galaxy: Galaxy

    // Creates a new, empty Star.
    init() { }

    // Creates a new Star with all properties set.
    init(id: UUID? = nil, name: String, galaxyID: UUID) {
        self.id = id
        self.name = name
        self.$galaxy.id = galaxyID
    }
}
```

### 父类

新的`Star`模型与`Galaxy`非常相似，但有一个新的字段类型：`@Parent`.

```swift
@Parent(key: "galaxy_id")
var galaxy: Galaxy
```

父类属性是一个存储另一个模型的标识符的字段。持有引用的模型被称为"子类"，被引用的模型被称为"父类"。这种类型的关系也被称为"一对多"。该属性的`key`参数指定了在数据库中用于存储父类键的字段名。

在init方法中，使用`$galaxy`来设置父类标识符。

```swift
self.$galaxy.id = galaxyID
```

通过在父属性的名字前加上`$`，你可以访问底层的属性包装器。这是访问内部`@Field`的必要条件，它存储了实际的标识符值。

!!!另见 

​	请查看 Swift Evolution 中关于属性包装器的建议，了解更多信息。[[SE-0258] Property Wrappers](https://github.com/apple/swift-evolution/blob/master/proposals/0258-property-wrappers.md)

接下来，创建一个迁移，为处理`Star`的数据库做准备。

```swift
struct CreateStar: Migration {
    // Prepares the database for storing Star models.
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("stars")
            .id()
            .field("name", .string)
            .field("galaxy_id", .uuid, .references("galaxies", "id"))
            .create()
    }

    // Optionally reverts the changes made in the prepare method.
    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("stars").delete()
    }
}
```

这与星系的迁移基本相同，只是多了一个字段来存储父星系的标识符。

```swift
field("galaxy_id", .uuid, .references("galaxies", "id"))
```

这个字段指定了一个可选的约束条件，告诉数据库这个字段的值引用了"galaxies"模式中的字段"id"。这也被称为外键，有助于确保数据的完整性。

一旦创建了迁移，就把它添加到`app.migrations`中，放在`CreateGalaxy`迁移之后。

```swift
app.migrations.add(CreateGalaxy())
app.migrations.add(CreateStar())
```

由于迁移是按顺序进行的，而且`CreateStar`引用的是星系模式，所以排序很重要。最后，[运行迁移](notion://www.notion.so/cainluo/Fluent-fcea5299577d44cfa743c4e5c02a66a3#migrate)来准备数据库。

添加一个用于创建新stars的路由。

```swift
app.post("stars") { req -> EventLoopFuture<Star> in
    let star = try req.content.decode(Star.self)
    return star.create(on: req.db)
        .map { star }
}
```

使用下面的HTTP请求创建一个新的星体，引用之前创建的galaxy。

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

你应该看到新创建的星体有一个独特的标识符返回。

```json
{
    "id": ...,
    "name": "Sun",
    "galaxy": {
        "id": ...
    }
}
```

### 子类

现在让我们来看看如何利用Fluent的急于加载功能，在`GET /galaxies`路由中自动返回星系的星星。给`Galaxy`模型添加以下属性。

```swift
// All the Stars in this Galaxy.
@Children(for: \.$galaxy)
var stars: [Star]
```

`@Children`属性包装器是`@Parent`的反面。它需要一个通往孩子的`@Parent`字段的关键路径作为`for`参数。它的值是一个子模型的数组，因为可能存在零个或多个子模型。不需要改变galaxy的迁移，因为这种关系所需的所有信息都存储在`Star`上。

### 急于加载

现在关系已经完成，你可以使用查询生成器上的`with`方法来自动获取并序列化星系-恒星关系。

```swift
app.get("galaxies") { req in
    Galaxy.query(on: req.db).with(\.$stars).all()
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

### 兄弟姐妹

最后一种关系是多对多的关系，即兄弟姐妹关系。 创建一个`Tag`模型，有一个`id`和`name`字段，我们将用它来标记具有某些特征的明星。

```swift
final class Tag: Model, Content {
    // Name of the table or collection.
    static let schema: String = "tags"

    // Unique identifier for this Tag.
    @ID(key: .id)
    var id: UUID?

    // The Tag's name.
    @Field(key: "name")
    var name: String

    // Creates a new, empty Tag.
    init() {}

    // Creates a new Tag with all properties set.
    init(id: UUID? = nil, name: String) {
        self.id = id
        self.name = name
    }
}
```

一个标签可以有很多星，一个星可以有很多标签，使它们成为兄弟姐妹。 两个模型之间的兄弟姐妹关系需要第三个模型（称为pivot）来保存关系数据。 每个`StarTag`模型对象将代表一个单一的星到标签的关系，持有一个单一的`Star`和一个单一的`Tag`的ID。

```swift
final class StarTag: Model {
    // Name of the table or collection.
    static let schema: String = "star_tag"

    // Unique identifier for this pivot.
    @ID(key: .id)
    var id: UUID?

    // Reference to the Tag this pivot relates.
    @Parent(key: "tag_id")
    var tag: Tag

    // Reference to the Star this pivot relates.
    @Parent(key: "star_id")
    var star: Star

    // Creates a new, empty pivot.
    init() {}

    // Creates a new pivot with all properties set.
    init(tagID: UUID, starID: UUID) {
        self.$tag.id = tagID
        self.$star.id = starID
    }

}
```

现在让我们更新我们新的`Tag`模型，为所有包含标签的星星添加一个`Stars`属性：

```swift
@Siblings(through: StarTag.self, from: \.$tag, to: \.$star)
var stars: [Star]
```

`@Siblings`属性包装器需要三个参数。第一个参数是我们之前创建的枢轴模型，`StarTag`。接下来的两个参数是枢轴模型的父关系的关键路径。`from`关键路径是枢轴与当前模型的父关系，在这里是`Tag`。`to`关键路径是枢轴与相关模型的父关系，在这里是`Star`。这三个参数一起创建了一个从当前模型`Tag`，通过枢轴`StarTag`，到所需模型`Star`的关系。现在让我们用它的兄弟姐妹属性来更新我们的`Star`模型，它是我们刚刚创建的模型的反面：

```swift
@Siblings(through: StarTag.self, from: \.$star, to: \.$tag)
var tags: [Tag]
```

这些兄弟姐妹的属性依靠`StarTag`进行存储，所以我们不需要更新`Star`迁移，但我们需要为新的`Tag`和`StarTag`模型创建迁移。

```swift
struct CreateTag: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("tags")
            .id()
            .field("name", .string)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("tags").delete()
    }

}

struct CreateStarTag: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("star_tag")
            .id()
            .field("star_id", .uuid, .required, .references("stars", "id"))
            .field("tag_id", .uuid, .required, .references("tags", "id"))
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("star_tag").delete()
    }
}
```

然后在configure.swift中添加迁移的内容。

```swift
app.migrations.add(CreateTag())
app.migrations.add(CreateStarTag())
```

现在我们想给星星添加标签。 在创建了一条创建新标签的路线后，我们需要创建一条将标签添加到现有星星的路线。

```swift
app.post("star", ":starID", "tag", ":tagID") { req -> EventLoopFuture<HTTPStatus> in
    let star = Star.find(req.parameters.get("starID"), on: req.db)
        .unwrap(or: Abort(.notFound))
    let tag = Tag.find(req.parameters.get("tagID"), on: req.db)
        .unwrap(or: Abort(.notFound))
    return star.and(tag).flatMap { (star, tag) in
        star.$tags.attach(tag, on: req.db)
    }.transform(to: .ok)
}
```

这个路由包括我们想要相互关联的star和tag的ID的参数路径组件。 如果我们想在一个ID为1的明星和一个ID为2的标签之间建立关系，我们会向`/star/1/tag/2`发送一个**POST**请求，我们会收到一个HTTP响应代码作为回报。 首先，我们在数据库中查找明星和标签，以确保这些是有效的ID。 然后，我们通过将标签附加到星星的标签上来创建关系。 由于星星的`tags`属性是与另一个模型的关系，我们需要通过它的`@Siblings`属性包装器，使用`$`操作符来访问它。

默认情况下，兄弟姐妹是不被获取的，所以如果我们想在查询时加入`with`方法，就需要更新我们对星星的获取路径。

```swift
app.get("stars") { req in
    Star.query(on: req.db).with(\.$tags).all()
}
```

## 生命周期

为了创建响应你的`Model`事件的钩子，你可以为你的模型创建中间件。你的中间件必须符合`ModelMiddleware`。

下面是一个简单的中间件的例子：

```swift
struct GalaxyMiddleware: ModelMiddleware {
    // Runs when a model is created
    func create(model: Galaxy, on db: Database, next: AnyModelResponder) -> EventLoopFuture<Void> {
        return next.create(model, on: db)
    }

    // Runs when a model is updated
    func update(model: Galaxy, on db: Database, next: AnyModelResponder) -> EventLoopFuture<Void> {
        return next.update(model, on: db)
    }

    // Runs when a model is soft deleted
    func softDelete(model: Galaxy, on db: Database, next: AnyModelResponder) -> EventLoopFuture<Void> {
        return next.softDelete(model, on: db)
    }

    // Runs when a soft deleted model is restored
    func restore(model: Galaxy, on db: Database, next: AnyModelResponder) -> EventLoopFuture<Void> {
        return next.restore(model , on: db)
    }

    // Runs when a model is deleted
    // If the "force" parameter is true, the model will be permanently deleted,
    // even when using soft delete timestamps.
    func delete(model: Galaxy, force: Bool, on db: Database, next: AnyModelResponder) -> EventLoopFuture<Void> {
        return next.delete(model, force: force, on: db)
    }
}
```

这些方法中的每一个都有一个默认的实现，所以你只需要包括你需要的方法。你应该在下一个`AnyModelResponder`上返回相应的方法，这样Fluent才会继续处理这个事件。

!!!重要提示 

​	中间件只对函数中提供的`Model`类型的生命周期事件做出响应。在上面的例子中，`GalaxyMiddleware`将对Galaxy模型的事件做出响应。

使用这些方法，你可以在事件完成之前和之后执行行动。 在事件完成后，可以使用.flatMap()对从下一个响应者返回的未来进行执行操作。 比如说。

```swift
struct GalaxyMiddleware: ModelMiddleware {
    func create(model: Galaxy, on db: Database, next: AnyModelResponder) -> EventLoopFuture<Void> {

        // The model can be altered here before it is created
        model.name = "<New Galaxy Name>"

        return next.create(model, on: db).flatMap {
            // Once the galaxy has been created, the code here will be executed
            print ("Galaxy \(model.name) was created")
        }
    }
}
```

一旦你创建了你的中间件，你必须在`Application`的数据库中间件配置中注册它，这样Vapor就会使用它。在`configure.swift`中添加。

```swift
app.databases.middleware.use(GalaxyMiddleware(), on: .psql)
```

## 时间戳

Fluent提供了通过在模型中指定`Timestamp`字段来跟踪模型的创建和更新时间的能力。Fluent会在必要时自动设置这些字段。你可以像这样添加这些字段。

```swift
@Timestamp(key: "created_at", on: .create)
var createdAt: Date?

@Timestamp(key: "updated_at", on: .update)
var updatedAt: Date?
```

!!!信息 

​	你可以为这些字段使用任何名称/键。`created_at` / `updated_at`, 仅供说明之用。

时间戳在迁移中被添加为字段，使用`.datetime`数据类型。

```swift
database.schema(...)
    ...
    .field("created_at", .datetime)
    .field("updated_at", .datetime)
    .create()
```

### 软删除

软删除将一个项目在数据库中标记为已删除，但实际上并没有删除它。例如，当你有数据保留的要求时，这可能是有用的。在Fluent中，它通过设置一个删除的时间戳来工作。默认情况下，软删除的项目不会出现在查询中，并且可以在任何时候被恢复。

与创建和删除的时间戳类似，要在一个模型中启用软删除，只需为`.delete`设置一个删除的时间戳。

```swift
@Timestamp(key: "deleted_at", on: .delete)
var deletedAt: Date?
```

在一个有删除时间戳属性的模型上调用`Model.delete(on:)`将自动软删除它。

如果你需要执行一个包括软删除项目的查询，你可以在你的查询中使用`withDeleted()`。

```swift
// Get all galaxies including soft-deleted ones.
Galaxy.query(on: db).withDeleted().all()
```

你可以用`restore(on:)`来恢复一个软删除的模型：

```swift
// Restore galaxy
galaxy.restore(on: db)
```

要永久地删除一个有删除时间戳的项目，请使用`force`参数。

```swift
// Permanently delete
galaxy.delete(force: true, on: db)
```

## 接下来

恭喜你创建了你的第一个模型和迁移，并进行了基本的创建和读取操作。关于所有这些功能的更深入的信息，请查看Fluent指南中各自的章节。