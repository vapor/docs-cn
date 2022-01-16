# 高级

Fluent致力于创建一个通用的、与数据库无关的API来处理你的数据。这使得无论你使用哪种数据库驱动，都能更容易地学习 Fluent。创建通用的API也可以让你的数据库工作在Swift中感觉更自如。

然而，你可能需要使用你的底层数据库驱动的某个功能，而这个功能还没有通过Fluent支持。本指南涵盖了Fluent中只适用于某些数据库的高级模式和API。

## SQL

所有的Fluent的SQL数据库驱动都是建立在[SQLKit](https://github.com/vapor/sql-kit)之上的。这种通用的SQL实现在Fluent的`FluentSQL`模块中与Fluent一起提供。

### SQL数据库

任何Fluent的 "数据库 "都可以被转换为 "SQLDatabase"。这包括`req.db`, `app.db`, 传递给`Migration`的`数据库`，等等。

```swift
import FluentSQL

if let sql = req.db as? SQLDatabase {
    // 底层数据库驱动是SQL。
    let planets = try await sql.raw("SELECT * FROM planets").all(decoding: Planet.self)
} else {
    // 底层数据库驱动是_not_ SQL。
}
```

只有当底层数据库驱动是一个SQL数据库时，这种投射才会起作用。在[SQLKit的README](https://github.com/vapor/sql-kit)中了解更多关于`SQLDatabase`的方法。

### 特定的SQL数据库

你也可以通过导入驱动来投递到特定的SQL数据库。

```swift
import FluentPostgresDriver

if let postgres = req.db as? PostgresDatabase {
    // 底层数据库驱动是PostgreSQL。
    postgres.simpleQuery("SELECT * FROM planets").all()
} else {
    // 底层数据库不是PostgreSQL。
}
```

在撰写本文时，支持以下SQL驱动。

|数据库|驱动程序|库|
|-|-|-|
|`PostgresDatabase`|[vapor/fluent-postgres-driver](https://github.com/vapor/fluent-postgres-driver)|[vapor/postgres-nio](https://github.com/vapor/postgres-nio)|
|`MySQLDatabase`|[vapor/fluent-mysql-driver](https://github.com/vapor/fluent-mysql-driver)|[vapor/mysql-nio](https://github.com/vapor/mysql-nio)|
|`SQLiteDatabase`|[vapor/fluent-sqlite-driver](https://github.com/vapor/fluent-sqlite-driver)|[vapor/sqlite-nio](https://github.com/vapor/sqlite-nio)|

请访问该库的README以了解更多关于数据库特定API的信息。

### SQL自定义

几乎所有的Fluent查询和模式类型都支持".custom "情况。这可以让你利用Fluent尚不支持的数据库功能。

```swift
import FluentPostgresDriver

let query = Planet.query(on: req.db)
if req.db is PostgresDatabase {
    // ILIKE支持。
    query.filter(\.$name, .custom("ILIKE"), "earth")
} else {
    // ILIKE不支持。
    query.group(.or) { or in
        or.filter(\.$name == "earth").filter(\.$name == "Earth")
    }
}
query.all()
```

SQL数据库在所有`.custom'情况下都支持`String'和`SQLExpression'。`FluentSQL`模块为常见的使用情况提供方便的方法。

```swift
import FluentSQL

let query = Planet.query(on: req.db)
if req.db is SQLDatabase {
    // 底层数据库驱动是SQL。
    query.filter(.sql(raw: "LOWER(name) = 'earth'"))
} else {
    // 底层数据库驱动是_not_ SQL。
}
```

下面是一个通过".sql(raw:) "便利性使用模式生成器的".custom "的例子。

```swift
import FluentSQL

let builder = database.schema("planets").id()
if database is MySQLDatabase {
    // 底层数据库驱动是MySQL。
    builder.field("name", .sql(raw: "VARCHAR(64)"), .required)
} else {
    // 底层数据库驱动是_not_ MySQL。
    builder.field("name", .string, .required)
}
builder.create()
```

## MongoDB

Fluent MongoDB是[Fluent](../fluent/overview.md)和[MongoKitten](https://github.com/OpenKitten/MongoKitten/)驱动之间的集成。它利用Swift的强类型系统和Fluent的数据库无关的接口，使用MongoDB。

MongoDB中最常见的标识符是ObjectId。你可以使用`@ID(custom: .id)`为你的项目使用这个。
如果你需要用SQL使用相同的模型，不要使用`ObjectId`。使用`UUID'代替。

```swift
final class User: Model {
    // 表或集合的名称。
    static let schema = "users"

    // 该用户的唯一标识符。
    // 在这种情况下，使用ObjectId。
    // Fluent推荐默认使用UUID，但也支持ObjectId。
    @ID(custom: .id)
    var id: ObjectId?

    // 用户的电子邮件地址
    @Field(key: "email")
    var email: String

    // 用户的密码以BCrypt哈希值的形式存储。
    @Field(key: "password")
    var passwordHash: String

    // 创建一个新的、空的用户实例，供Fluent使用。
    init() { }

    // 创建一个新的用户，并设置所有属性。
    init(id: ObjectId? = nil, email: String, passwordHash: String, profile: Profile) {
        self.id = id
        self.email = email
        self.passwordHash = passwordHash
        self.profile = profile
    }
}
```

### 数据建模

在MongoDB中，模型的定义与其他Fluent环境相同。SQL数据库和MongoDB的主要区别在于关系和架构。

在SQL环境中，为两个实体之间的关系创建连接表是非常常见的。然而，在MongoDB中，可以使用数组来存储相关的标识符。由于MongoDB的设计，用嵌套的数据结构来设计你的模型更加有效和实用。

### 灵活的数据

你可以在MongoDB中添加灵活的数据，但是这段代码在SQL环境中无法工作。
为了创建分组的任意数据存储，你可以使用`Document`。

```swift
@Field(key: "document")
var document: Document
```

Fluent不能支持对这些值的严格类型查询。你可以在你的查询中使用点符号的关键路径进行查询。
这在MongoDB中被接受，用于访问嵌套值。

```swift
Something.query(on: db).filter("document.key", .equal, 5).first()
```

### 原始访问

要访问原始的`MongoDatabase`实例，请将数据库实例投给`MongoDatabaseRepresentable`。

```swift
guard let db = req.db as? MongoDatabaseRepresentable else {
  throw Abort(.internalServerError)
}

let mongodb = db.raw
```

在这里，你可以使用所有的MongoKitten APIs。
