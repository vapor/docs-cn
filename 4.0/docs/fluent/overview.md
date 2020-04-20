# Fluent

Fluent 是一个 Swift 的 [ORM](https://en.wikipedia.org/wiki/Object-relational_mapping) 库。他提供了一个非常易用的 Swift 语言的数据库接口。使用 Fluent 时，你需要建立数据库模型，这些模型可以表示每个数据库表里的内容和类型。然后你就可以通过这些模型来添加、读取、更改或删除数据，这样你就不需要写 SQL 命令了。

## 配置

制作新 Vapor 项目时，使用 `vapor new` 之后，在问是否使用 Fluent 时回答 "yes" 然后选择你的数据库驱动。之后 Vapor 工具会自动填好依赖的库，还会添加一些基础配置代码。

### 向现有的项目添加 Fluent

如果你有一个现有的项目需要使用Fluent，你需要向你的 [Swift Package](../spm.md) 添加两个依赖项目：

- [vapor/fluent](https://github.com/vapor/fluent)@4.0.0
- 一个或者多个 Fluent 驱动

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

加完依赖项目之后，你可以在 `configure.swift` 使用 `app.databases` 配置数据库。

```swift
import Fluent
import Fluent<db>Driver

app.databases.use(<db config>, as: <identifier>)
```

以下每个 Fluent 驱动的说明都有配置的详细信息。

### 驱动
Fluent 现在支持4种数据库。你可以在 GitHub 上搜索 [`fluent-driver`](https://github.com/topics/fluent-database) 标签查询完整的官方以及第三方的驱动列表。

#### PostgreSQL

PostgreSQL 是一个开源的，符合标准 SQL 的数据库。它可以很容易的在很多服务器供应商上配置，这是 Fluent **推荐**使用的数据库驱动。

若想使用PostgreSQL，你需要在你的 Swift Package 里添加以下依赖项：

```swift
.package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.0.0-beta")
```

```swift
.product(name: "FluentPostgresDriver", package: "fluent-postgres-driver")
```

添加完依赖项后，在 `configure.swift` 里使用 `app.databases.use` 配置连接信息，包括用户名和密码。

```swift
import Fluent
import FluentPostgresDriver

app.databases.use(.postgres(hostname: "localhost", username: "vapor", password: "vapor", database: "vapor"), as: .psql)
```

你还可以直接使用一个快捷链接配置数据库信息。

```swift
try app.databases.use(.postgres(url: "<connection string>"), as: .psql)
```

#### SQLite

SQLite 是一个开源的，内嵌式的 SQL 数据库。它非常简洁，非常适合制作原型和测试时使用。

若想使用 SQLite，添加以下依赖项。

```swift
.package(url: "https://github.com/vapor/fluent-sqlite-driver.git", from: "4.0.0-beta")
```

```swift
.product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver")
```

之后在 `configure.swift` 里使用 `app.databases.use` 配置 SQLite。

```swift
import Fluent
import FluentSQLiteDriver

app.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite)
```

你还可以设置一个在内存里临时存储的 SQLite 数据库。

```swift
app.databases.use(.sqlite(.memory), as: .sqlite)
```

如果你使用内存里的数据库，你需要让Fluent自动迁移数据。在添加完需要迁移的数据后，调用  `app.autoMigrate()`，或者在启动时传入 `--auto-migrate`。

```swift
app.migrations.add(CreateTodo())
try app.autoMigrate().wait()
```

#### MySQL

MySQL 是一个非常流行的开源 SQL 数据库。很多服务器供应商都支持它。这个驱动还支持 MariaDB。

如果你想使用 MySQL，添加以下的依赖项：

```swift
.package(url: "https://github.com/vapor/fluent-mysql-driver.git", from: "4.0.0-beta")
```

```swift
.product(name: "FluentMySQLDriver", package: "fluent-mysql-driver")
```

添加完后，在 `configure.swift` 里使用 `app.databases.use` 配置连接信息。

```swift
import Fluent
import FluentMySQLDriver

app.databases.use(.mysql(hostname: "localhost", username: "vapor", password: "vapor", database: "vapor"), as: .mysql)
```

你还可以直接使用一个快捷链接配置数据库信息。

```swift
try app.databases.use(.mysql(url: "<connection string>"), as: .mysql)
```

#### MongoDB

MongoDB 是一个很有名的 NoSQL 数据库，他专门为开发者而设计。这个驱动支持所有服务器供应商以及自己安装的版本3.4以上的MongoDB数据库。

如果你想使用MongoDB，添加以下的依赖项：

```swift
.package(name: "FluentMongoDriver", url: "https://github.com/vapor/fluent-mongo-driver.git", from: "1.0.0"),
```

```swift
.product(name: "FluentMongoDriver", package: "fluent-mongo-driver")
```

添加完后，在 `configure.swift` 里使用 `app.databases.use` 配置连接信息。

你需要一个含有连接信息的字符串。[详情请见这里](https://docs.mongodb.com/master/reference/connection-string/index.html)。

```swift
import Fluent
import FluentMongoDriver

try app.databases.use(.mongo(connectionString: "<connection string>"), as: .mongo)
```

## 模型

一个模型可以代表一种固定的数据结构，比如一个表。模型可以有一个或者多个 field，每个 field 都可以存储一个支持 Codable 的数据类型。所有模型都需要有一个UUID。你的模型需要使用 Swift 的属性包装器 (Property Wrappers) 去表示每个 field 的 id，和其他更复杂的关系。看一看下面这个样例模型，它代表着一个宇宙星系。

```swift
final class Galaxy: Model {
    // 数据库表的名字
    static let schema = "galaxies"

    // 每个星系的UUID
    @ID(key: .id)
    var id: UUID?

    // 星系的名字
    @Field(key: "name")
    var name: String

    // 制作一个新的星系
    init() { }

    // 制作一个星系，并设好所有属性
    init(id: UUID? = nil, name: String) {
        self.id = id
        self.name = name
    }
}
```

如果你想制作一个新模型，制作一个新类，并让他遵守 `Model` 代理。

!!! 提示
    建议你将模型的类设为 `final`，这样可以提升性能和更简单的遵守协议。

遵守 `Model` 协议的第一件事就是添加一个 `schema` 的静态属性

```swift
static let schema = "galaxies"
```

这个属性告诉 Fluent 哪个模型对照着哪个表。这可以是一个已经存在的数据库表，或者是一个你马上要从过[数据迁移](#_5)制作的表。

### 标示符

下一个需求是一个 `id` 属性。

```swift
@ID(key: .id)
var id: UUID?
```

这个属性必须使用 `@ID` 属性包装器。Fluent 建议使用 `UUID` 类和 `.id` field key，这样可以让他支持所有 Fluent 的驱动。

如果你想使用一个你自己的标识符类 (比如 `Int`) 或者你自己的标识符 field key，你可以使用 `@ID(custom:)`。

### Fields

添加一个标识符后，你可以添加一个或者多个 fields 以便存储你的信息。在我们的例子里，我们只添加了一个 field，他是宇宙星系的名字。

```swift
@Field(key: "name")
var name: String
```

对于普通的 field。与 `@ID` 一样，`key` 参数代表着这个 field 在数据库表里的名字。这个 key 可以和 Swift 模型变量名不一样。比如说，你可以在数据库里使用 `snake_case` 代表 Swift 模型里的 `camelCase` 变量。

每一个模型需要有一个初始化程序。

```swift
init() { }
```

最后，你还可以添加你自己的初始化程序。

```swift
init(id: UUID? = nil, name: String) {
    self.id = id
    self.name = name
}
```

使用自定义初始化程序可以避免很多错误。比如，如果你添加了新变量并更改了自定义初始化程序，你在你更改整个服务器程序使用新初始化程序之前，你的程序里会有编译错误。

## 数据迁移

如果你的数据库需要固定数据结构，比如 SQL 数据库，你需要制作一个数据迁移。数据迁移时你还可以添加一些默认信息进数据库。如果你需要制作一个数据迁移，你需要制作一个新的类并让他遵守 `Migration` 协议。看看下面的这个样例。

```swift
struct CreateGalaxy: Migration {
    // 预备数据库存储Galaxy
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("galaxies")
            .id()
            .field("name", .string)
            .create()
    }

    // 撤回数据库迁移
    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("galaxies").delete()
    }
}
```

`prepare` 这个方法用来预备数据库来存储刚才的 `Galaxy` 模型。

### Schema

在刚才的 `prepare` 里，`database.schema(_:)` 制作了一个新的 `SchemaBuilder`。你可以向他添加一个或者多个 `field`，最后调用 `create()` 即可把配置写入数据库。

每一个 field 有一个名字，一个类型，和限制。限制不必需提供。

```swift
field(<name>, <type>, <optional constraints>)
```

`SchemaBuilder` 还有一个 `id()` 功能，你可以用它添加默认的 `@ID` 属性。

撤回数据迁移会撤回迁移时的任何更改。在这个例子里，我们删除了 `Galaxy` 这个表。

建立完迁移以后，在 `configure.swift` 里使用 `app.migrations` 添加你的数据迁移。

```swift
app.migrations.add(CreateGalaxy())
```

### 迁移数据

若想运行数据迁移，在命令行调用 `vapor run migrate`，或者在 Xcode 里添加 `migrate` 启动项。

```
$ vapor run migrate
Migrate Command: Prepare
The following migration(s) will be prepared:
+ CreateGalaxy on default
Would you like to continue?
y/n> y
Migration successful
```

## 调取数据

恭喜你成功制作了一个模型！🎉 现在你可以开始调取信息了。

### All

以下程序可以调取数据库里所有 `Galaxy`。

```swift
app.get("galaxies") { req in
    Galaxy.query(on: req.db).all()
}
```

你可以让 `Galaxy` 遵守 `Content`，即可直接在路由闭包里返回它。

```swift
final class Galaxy: Model, Content {
    ...
}
```

`Galaxy.query` 为 `Galaxy` 模型制作了一个新的 `QueryBuilder`。`req.db` 可以直接调取默认数据库。最后，`all()` 返回数据库里所有行。

运行你的软件并访问 `GET /galaxies`，你会看到服务器返回了一个空数组。现在让我们制作一个可以添加信息的路由吧！

### Create

继续根据 RESTful 的规则前进，调用 `POST /galaxies` 时应该向数据库里添加一个新的 `Galaxy`。所有遵守 `Model` 的都是 `Codable`。你可以直接从请求的内容中解码成 `Galaxy`。

```swift
app.post("galaxies") { req -> EventLoopFuture<Galaxy> in
    let galaxy = try req.content.decode(Galaxy.self)
    return galaxy.create(on: req.db)
        .map { galaxy }
}
```

!!! 看一看
    进入[内容 &rarr; 概述](../content.md)即可获得关于解码的更多信息。

当你有一个 `Galaxy` 的对象后，调用 `create(on:)` 即可保存至数据库。`create(on:)` 会返回一个 `EventLoopFuture<Void>`，你可以使用 `map` 返回新保存的模型。

运行你的软件，并发送一下请求。

```http
POST /galaxies HTTP/1.1
content-length: 21
content-type: application/json

{
    "name": "Milky Way"
}
```

你会收到服务器返回给你的新制作的模型。

```json
{
    "id": ...,
    "name": "Milky Way"
}
```

现在再请求 `GET /galaxies` 即可获得一个含有你新保存的模型的数组。


## Relations

What are galaxies without stars! Let's take a quick look at Fluent's powerful relational features by adding a one-to-many relation between `Galaxy` and a new `Star` model.

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

### Parent

The new `Star` model is very similar to `Galaxy` except for a new field type: `@Parent`.

```swift
@Parent(key: "galaxy_id")
var galaxy: Galaxy
```

The parent property is a field that stores another model's identifier. The model holding the reference is called the "child" and the referenced model is called the "parent". This type of relation is also known as "one-to-many". The `key` parameter to the property specifies the field name that should be used to store the parent's key in the database.

In the init method, the parent identifier is set using `$galaxy`.

```swift
self.$galaxy.id = galaxyID
```

 By prefixing the parent property's name with `$`, you access the underlying property wrapper. This is required for getting access to the internal `@Field` that stores the actual identifier value.

!!! seealso
    Check out the Swift Evolution proposal for property wrappers for more information: [[SE-0258] Property Wrappers](https://github.com/apple/swift-evolution/blob/master/proposals/0258-property-wrappers.md)

Next, create a migration to prepare the database for handling `Star`.


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

This is mostly the same as galaxy's migration except for the additional field to store the parent galaxy's identifier.

```swift
field("galaxy_id", .uuid, .references("galaxies", "id"))
```

This field specifies an optional constraint telling the database that the field's value references the field "id" in the "galaxies" schema. This is also known as a foreign key and helps ensure data integrity.

Once the migration is created, add it to `app.migrations` after the `CreateGalaxy` migration.

```swift
app.migrations.add(CreateGalaxy())
app.migrations.add(CreateStar())
```

Since migrations run in order, and `CreateStar` references the galaxies schema, ordering is important. Finally, [run the migrations](#migrate) to prepare the database.

Add a route for creating new stars.

```swift
app.post("stars") { req -> EventLoopFuture<Star> in
    let star = try req.content.decode(Star.self)
    return star.create(on: req.db)
        .map { star }
}
```

Create a new star referencing the previously created galaxy using the following HTTP request.

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

You should see the newly created star returned with a unique identifier.

```json
{
    "id": ...,
    "name": "Sun",
    "galaxy": {
        "id": ...
    }
}
```

### Children

Now let's take a look at how you can utilize Fluent's eager-loading feature to automatically return a galaxy's stars in the `GET /galaxies` route. Add the following property to the `Galaxy` model.

```swift
// All the Stars in this Galaxy.
@Children(for: \.$galaxy)
var stars: [Star]
```

The `@Children` property wrapper is the inverse of `@Parent`. It takes a key-path to the child's `@Parent` field as the `for` argument. Its value is an array of children since zero or more child models may exist. No changes to the galaxy's migration are needed since all the information needed for this relation is stored on `Star`.

### Eager Load

Now that the relation is complete, you can use the `with` method on the query builder to automatically fetch and serialize the galaxy-star relation.

```swift
app.get("galaxies") { req in
    Galaxy.query(on: req.db).with(\.$stars).all()
}
```

A key-path to the `@Children` relation is passed to `with` to tell Fluent to automatically load this relation in all of the resulting models. Build and run and send another request to `GET /galaxies`. You should now see the stars automatically included in the response.

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


### Siblings

The last type of relationship is many-to-many, or sibling relationship.  Create a `Tag` model with an `id` and `name` field that we'll use to tag stars with certain characteristics.  

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

A tag can have many stars and a star can have many tags making them siblings.  A sibling relationship between two models requires a third model (called a pivot) that holds the relationship data.  Each of these `StarTag` model objects will represent a single star-to-tag relationship holding the ids of a single `Star` and a single `Tag`:

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

Now let's update our new `Tag` model to add a `stars` property for all the stars that contain a tag:

```swift
@Siblings(through: StarTag.self, from: \.$tag, to: \.$star)
var stars: [Star]
```

The` @Siblings` property wrapper takes three arguments. The first argument is the pivot model that we created earlier, `StarTag`. The next two arguments are key paths to the pivot model's parent relations. The `from` key path is the pivot's parent relation to the current model, in this case `Tag`. The `to` key path is the pivot's parent relation to the related model, in this case `Star`. These three arguments together create a relation from the current model `Tag`, through the pivot `StarTag`, to the desired model `Star`. Now let's update our `Star` model with its siblings property which is the inverse of the one we just created:

```swift
@Siblings(through: StarTag.self, from: \.$star, to: \.$tag)
var tags: [Tag]
```

These siblings properties rely on `StarTag` for storage so we don't need to update the `Star` migration, but we do need to create migrations for the new `Tag` and `StarTag` models:

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
            .field("star_id", .uuid, .required, .references("star", "id"))
            .field("tag_id", .uuid, .required, .references("star", "id"))
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("star_tag").delete()
    }
}
```

And then add the migrations in configure.swift:

```swift
app.migrations.add(CreateTag())
app.migrations.add(CreateStarTag())
```

Now we want to add tags to stars.  After creating a route to create a new tag, we need to create a route that will add a tag to an existing star.

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

This route includes parameter path components for the IDs of star and tag that we want to associate with one another.  If we want to create a relationship between a star with an ID of 1 and a tag with an ID of 2, we'd send a **POST** request to  `/star/1/tag/2` and we'd receive an HTTP response code in return.  First, we lookup the star and tag in the database to ensure these are valid IDs.  Then, we create the relationship by attaching the tag to the star's tags.  Since the star's `tags` property is a relationship to another model, we need to access it via it's `@Siblings` property wrapper by using the `$` operator.

Siblings aren't fetched by default so we need to update our get route for stars if we want include them when querying by inserting the `with` method:

```swift
app.get("stars") { req in
    Star.query(on: req.db).with(\.$tags).all()
}
```

## Lifecycle

To create hooks that respond to events on your `Model`, you can create middlewares for your model. Your middleware must conform to `ModelMiddleware`.

Here is an example of a simple middleware:

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

Each of these methods has a default implementation, so you only need to include the methods you require. You should return the corresponding method on the next `AnyModelResponder` so Fluent continues processing the event.

!!! Important
    The middleware will only respond to lifecycle events of the `Model` type provided in the functions. In the above example `GalaxyMiddleware` will respond to events on the Galaxy model.

Using these methods you can perform actions both before, and after the event completes.  Performing actions after the event completes can be done using using .flatMap() on the future returned from the next responder.  For example:

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

Once you have created your middleware, you must register it with the `Application`'s database middleware configuration so Vapor will use it. In `configure.swift` add:

```swift
app.databases.middleware.use(GalaxyMiddleware(), on: .psql)
```

## Timestamps

Fluent provides the ability to track creation and update times on models by specifying `Timestamp` fields in your model. Fluent automatically sets the fields when necessary. You can add these like so:

```swift
@Timestamp(key: "created_at", on: .create)
var createdAt: Date?

@Timestamp(key: "updated_at", on: .update)
var updatedAt: Date?
```

!!! Info
    You can use any name/key for these fields. `created_at` / `updated_at`, are only for illustration purposes

Timestamps are added as fields in a migration using the `.datetime` data type.

```swift
database.schema(...)
    ...
    .field("created_at", .datetime)
    .field("updated_at", .datetime)
    .create()
```

### Soft Delete

Soft deletion marks an item as deleted in the database but doesn't actually remove it. This can be useful when you have data retention requirements, for example. In Fluent, it works by setting a deletion timestamp. By default, soft deleted items won't appear in queries and can be restored at any time.

Similar to created and deleted timestamps, to enable soft deletion in a model just set a deletion timestamp for `.delete`:

```swift
@Timestamp(key: "deleted_at", on: .delete)
var deletedAt: Date?
```

Calling `Model.delete(on:)` on a model that has a delete timestamp property will automatically soft delete it.

If you need to perform a query that includes the soft deleted items, you can use `withDeleted()` in your query.

```swift
// Get all galaxies including soft-deleted ones.
Galaxy.query(on: db).withDeleted().all()
```

You can restore a soft deleted model with `restore(on:)`:

```swift
// Restore galaxy
galaxy.restore(on: db)
```

To permanently delete an item with an on-delete timestamp, use the `force` parameter:

```swift
// Permanently delete
galaxy.delete(force: true, on: db)
```

## Next Steps

Congratulations on creating your first models and migrations and performing basic create and read operations. For more in-depth information on all of these features, check out their respective sections in the Fluent guide.
