# 模型

模型代表存储在数据库中的表或集合中的数据。模型有一个或多个字段来存储可编码的值。所有模型都有一个唯一的标识符。属性包装器被用来表示标识符、字段和关系。

下面是一个有一个字段的简单模型的例子。注意，模型并不描述整个数据库模式，比如约束、索引和外键。模式是在[migrations](./migration.md)中定义的。模型的重点是表示存储在你的数据库模式中的数据。 

```swift
final class Planet: Model {
    // 表或集合的名称。
    static let schema = "planets"

    // 该Planet的唯一标识符。
    @ID(key: .id)
    var id: UUID?

    // Planet的名字。
    @Field(key: "name")
    var name: String

    // 创建一个新的、空的Planet。
    init() { }

    // 创建一个新的Planet，并设置所有属性。
    init(id: UUID? = nil, name: String) {
        self.id = id
        self.name = name
    }
}
```

## Schema

所有模型都需要一个静态的、只可获取的`schema`属性。这个字符串引用了这个模型所代表的表或集合的名称。

```swift
final class Planet: Model {
    // 表或集合的名称。
    static let schema = "planets"
}
```

当查询这个模型时，数据将被提取并存储到名为`planets`的模式中。

!!!提示
    模式名称通常是类名的复数和小写。

## 标识符

所有模型都必须有一个使用`@ID`属性包装器定义的`id`属性。这个字段唯一地标识了你的模型的实例。

```swift
final class Planet: Model {
    // 该Planet的唯一标识符。
    @ID(key: .id)
    var id: UUID?
}
```

默认情况下，`@ID`属性应该使用特殊的`.id`键，它可以解析为底层数据库驱动的适当键。对于SQL来说，这是`id`，对于NoSQL来说，这是`_id`。

`@ID`也应该是`UUID`类型。这是目前所有数据库驱动都支持的唯一标识符值。当模型被创建时，Fluent会自动生成新的UUID标识符。

`@ID`有一个可选的值，因为未保存的模型可能还没有一个标识符。要获得标识符或抛出一个错误，请使用`requireID`。

```swift
let id = try planet.requireID()
```

### 存在

`@ID`有一个`exists`属性，表示模型是否存在于数据库中。当你初始化一个模型时，其值是`false`。当你保存一个模型或从数据库中获取一个模型时，其值为`true`。这个属性是可变的。

```swift
if planet.$id.exists {
    // 这个模型存在于数据库中。
}
```

### 自定义标识符

Fluent支持使用`@ID(custom:)`重载的自定义标识符键和类型。

```swift
final class Planet: Model {
    // 该Planet的唯一标识符。
    @ID(custom: "foo")
    var id: Int?
}
```

上面的例子使用了一个`@ID`，有自定义键`"foo"`和标识符类型`Int`。这与使用自动递增主键的SQL数据库兼容，但与NoSQL不兼容。

自定义`@ID`允许用户使用`generatedBy`参数指定标识符的生成方式。

```swift
@ID(custom: "foo", generatedBy: .user)
```

`generatedBy`参数支持这些情况：

| 生成者      | 描述                                      |
| ----------- | ----------------------------------------- |
| `.user`     | `@ID`属性应该在保存一个新模型之前被设置。 |
| `.random`   | `@ID`值类型必须符合`RandomGeneratable`。  |
| `.database` | 预计数据库在保存时将产生一个值。          |

如果省略了`generatedBy`参数，Fluent将试图根据`@ID`值类型推断出一个合适的情况。例如，`Int`将默认为`.database`生成，除非另有规定。

## 初始化器

模型必须有一个空的初始化方法。

```swift
final class Planet: Model {
    // 创建一个新的、空的Planet。
    init() { }
}
```

Fluent内部需要这个方法来初始化查询返回的模型。它也被用于反射。

你可能想给你的模型添加一个方便的初始化器，接受所有属性。

```swift
final class Planet: Model {
    // 创建一个新的Planet，并设置所有属性。
    init(id: UUID? = nil, name: String) {
        self.id = id
        self.name = name
    }
}
```

使用方便的初始化器使得将来向模型添加新的属性更加容易。

## 字段

模型可以有零个或多个`@Field`属性用于存储数据。

```swift
final class Planet: Model {
    // 该Planet的名字
    @Field(key: "name")
    var name: String
}
```

字段要求明确定义数据库键。这并不要求与属性名称相同。

!!!提示
    Fluent建议数据库键使用`snake_case`，属性名使用`camelCase`。

字段值可以是任何符合`Codable`的类型。支持在`@Field`中存储嵌套结构和数组，但过滤操作受到限制。参见[`@Group`](#group)以获得替代方案。

对于包含可选值的字段，使用`@OptionalField`。

```swift
@OptionalField(key: "tag")
var tag: String?
```

## 关系

模型可以有零个或多个引用其他模型的关系属性，如 `@Parent`, `@Children`, 和 `@Siblings`。在[关系](./relations.md)部分了解更多关于关系的信息。

## 时间戳

`@Timestamp`是一种特殊的`@Field`类型，用于存储一个`Foundation.Date`。时间戳是由Fluent根据所选择的触发器自动设置的。

```swift
final class Planet: Model {
    // 这个Planet是什么时候创建的。
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    // 这个Planet最后更新的时间。
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
}
```

`@Timestamp`支持以下触发器。

| 触发器    | 描述                                                         |
| --------- | ------------------------------------------------------------ |
| `.create` | 当一个新的模型实例被保存到数据库时设置。                     |
| `.update` | 当一个现有的模型实例被保存到数据库时设置。                   |
| `.delete` | 当一个模型从数据库中被删除时设置。参见[软删除](#软删除)。 |

`@Timestamp`的日期值是可选的，在初始化一个新模型时应设置为`nil`。

### 时间戳格式

默认情况下，`@Timestamp`将使用基于你的数据库驱动的有效日期编码。你可以使用`format`参数来定制时间戳在数据库中的存储方式。

```swift
// 存储一个ISO 8601格式的时间戳，代表这个模型的最后更新时间。
// 这个模型最后一次被更新的时间。
@Timestamp(key: "updated_at", on: .update, format: .iso8601)
var updatedAt: Date?
```

可用的时间戳格式列举如下。

| 格式       | 描述                                                         | 类型   |
| ---------- | ------------------------------------------------------------ | ------ |
| `.default` | 为特定的数据库使用有效的日期时间编码。                       | Date   |
| `.iso8601` | [ISO 8601](https://en.wikipedia.org/wiki/ISO_8601)字符串。支持`withMilliseconds`参数。 | String |
| `.unix`    | 自Unix epoch以来的秒数，包括分数。                           | Double |

你可以使用`timestamp`属性直接访问原始时间戳值。

```swift
// 在这个ISO 8601上手动设置时间戳值
// 格式化的@Timestamp。
model.$updatedAt.timestamp = "2020-06-03T16:20:14+00:00"
```

### 软删除

在你的模型中添加一个使用`.delete`触发器的`@Timestamp`将启用软删除。

```swift
final class Planet: Model {
    // 这个Planet被删除时间
    @Timestamp(key: "deleted_at", on: .delete)
    var deletedAt: Date?
}
```

软删除的模型在删除后仍然存在于数据库中，但将不会在查询中返回。

!!!提示
    你可以手动设置一个删除时的时间戳到未来的一个日期。这可以作为一个到期日。

要强制将一个可软删除的模型从数据库中删除，使用 `delete` 中的 `force` 参数。

```swift
// 从数据库中删除，即使该模型 
// 是可以软删除的。
model.delete(force: true, on: database)
```

要恢复一个软删除的模型，使用`restore`方法。

```swift
// 清除删除时的时间戳，允许这个 
// 模型在查询中被返回。
model.restore(on: database)
```

要在查询中包括软删除的模型，使用 `withDeleted`。

```swift
// 获取所有的Planet，包括软删除。
Planet.query(on: database).withDeleted().all()
```

## Enum

`@Enum`是`@Field`的一种特殊类型，用于将字符串可表示的类型存储为本地数据库枚举。本地数据库枚举为你的数据库提供了一个额外的类型安全层，并且可能比原始枚举更有性能。

```swift
// 字符串可表示，动物类型的可编码枚举。
enum Animal: String, Codable {
    case dog, cat
}

final class Pet: Model {
    // 将动物的类型存储为本地数据库枚举。
    @Enum(key: "type")
    var type: Animal
}
```

只有符合`RawRepresentable`的类型，其中`RawValue`是`String`，才与`@Enum`兼容。`String`支持的枚举默认满足这一要求。

要存储一个可选的枚举，请使用`@OptionalEnum`。

数据库必须准备好通过迁移来处理枚举。更多信息请参见[enum](./schema.md#enum)。

### 原始枚举

任何由`Codable`类型支持的枚举，如`String`或`Int`，都可以存储在`@Field`中。它将作为原始值存储在数据库中。

## 组

`@Group`允许你将一组嵌套的字段作为一个单一的属性存储在你的模型上。与存储在`@Field`中的可编码结构不同，`@Group`中的字段是可查询的。Fluent通过将`@Group`作为一个平面结构存储在数据库中来实现这一点。

要使用`@Group`，首先要使用`Fields`协议定义你想存储的嵌套结构。这与`Model`非常相似，只是不需要标识符或模式名称。你可以在这里存储许多`Model`支持的属性，如`@Field`，`@Enum`，甚至另一个`@Group`。

```swift
// 一个有名字和动物类型的宠物。
final class Pet: Fields {
    // 宠物的名字。
    @Field(key: "name")
    var name: String

    // 宠物的类型。
    @Field(key: "type")
    var type: String

    // 创建一个新的、空的宠物。
    init() { }
}
```

在你创建了字段定义后，你可以把它作为`@Group`属性的值。

```swift
final class User: Model {
    // 用户的嵌套宠物。
    @Group(key: "pet")
    var pet: Pet
}
```

一个`@Group`的字段可以通过点语法访问。

```swift
let user: User = ...
print(user.pet.name) // String
```

你可以像平常一样使用属性包装器上的点语法查询嵌套字段。

```swift
User.query(on: database).filter(\.$pet.$name == "Zizek").all()
```

在数据库中，`@Group`被存储为一个平面结构，键由`_`连接。下面是一个例子，说明`User'在数据库中的样子。

| id   | name   | pet_name | pet_type |
| ---- | ------ | -------- | -------- |
| 1    | Tanner | Zizek    | Cat      |
| 2    | Logan  | Runa     | Dog      |

## Codable

模型默认符合`Codable`。这意味着你可以在Vapor的[内容API](../basics/content.md)中使用你的模型，只要加入对`Content`协议的符合性。

```swift
extension Planet: Content { }

app.get("planets") { req in 
    // 返回一个所有Planet的数组。
    Planet.query(on: req.db).all()
}
```

当从`Codable`序列化时，模型属性将使用它们的变量名而不是键。关系将被序列化为嵌套结构，任何急于加载的数据将被包括在内。

### 数据传输对象

模型默认的`Codable`一致性可以使简单的使用和原型设计更容易。然而，它并不适合于每一种使用情况。对于某些情况，你需要使用数据传输对象（DTO）。

!!! 提示
    DTO是一个单独的`Codable`类型，代表你想编码或解码的数据结构。

在接下来的例子中，假设有以下`User`模型。

```swift
// 简略的用户模型供参考。
final class User: Model {
    @ID(key: .id)
    var id: UUID?

    @Field(key: "first_name")
    var firstName: String

    @Field(key: "last_name")
    var lastName: String
}
```

DTO的一个常见用例是实现`PATCH`请求。这些请求只包括应该被更新的字段的值。如果缺少任何所需的字段，试图直接从这样的请求中解码`Model`将会失败。在下面的例子中，你可以看到一个DTO被用来解码请求数据并更新一个模型。

```swift
// PATCH /users/:id请求的结构。
struct PatchUser: Decodable {
    var firstName: String?
    var lastName: String?
}

app.patch("users", ":id") { req in 
    // 对请求数据进行解码。
    let patch = try req.content.decode(PatchUser.self)
    // 从数据库中获取所需的用户。
    return User.find(req.parameters.get("id"), on: req.db)
        .unwrap(or: Abort(.notFound))
        .flatMap 
    { user in
        // 如果提供了名字，则更新它。
        if let firstName = patch.firstName {
            user.firstName = firstName
        }
        // 如果提供了新的姓氏，就更新它。
        if let lastName = patch.lastName {
            user.lastName = lastName
        }
        // 保存用户并返回。
        return user.save(on: req.db)
            .transform(to: user)
    }
}
```

DTO的另一个常见的用例是定制你的API响应的格式。下面的例子显示了如何使用DTO来为响应添加一个计算字段。

```swift
// GET /users 响应的结构。
struct GetUser: Content {
    var id: UUID
    var name: String
}

app.get("users") { req in 
    // 从数据库中获取所有用户。
    User.query(on: req.db).all().flatMapThrowing { users in
        try users.map { user in
            // 将每个用户转换为GET返回类型。
            try GetUser(
                id: user.requireID(),
                name: "\(user.firstName) \(user.lastName)"
            )
        }
    }
}
```

即使DTO的结构与model的`Codable`一致性相同，把它作为一个单独的类型可以帮助保持大型项目的整洁。如果你需要改变你的模型属性，你不必担心会破坏你的应用程序的公共API。你也可以考虑把你的DTO放在一个单独的包里，可以与你的API的消费者共享。

由于这些原因，我们强烈建议尽可能地使用DTOs，特别是对于大型项目。

## 别名

`ModelAlias`协议可以让你在查询中唯一地识别一个被多次连接的模型。更多信息，请参阅[joins](./query.md#join)。

## 保存

要保存一个模型到数据库，请使用`save(on:)`方法。

```swift
planet.save(on: database)
```

这个方法将在内部调用`创建`或`更新`，取决于模型是否已经存在于数据库中。

### 创建

你可以调用`create`方法来保存一个新模型到数据库中。

```swift
let planet = Planet(name: "Earth")
planet.create(on: database)
```

`create`也可用于模型的数组。这在一个批次/查询中把所有的模型保存到数据库中。

```swift
// 批量创建的例子。
[earth, mars].create(on: database)
```

### 更新

你可以调用`update`方法来保存一个从数据库中获取的模型。

```swift
Planet.find(..., on: database).flatMap { planet in
    planet.name = "Earth"
    return planet.update(on: database)
}
```

## 查询

模型暴露了一个静态方法`query(on:)`，返回一个查询生成器。

```swift
Planet.query(on: database).all()
```

在[查询](./query.md)部分了解更多关于查询的信息。

## 查找

模型有一个静态的`find(_:on:)`方法，用于通过标识符查找一个模型实例。

```swift
Planet.find(req.parameters.get("id"), on: database)
```

如果没有找到具有该标识符的模型，该方法返回`nil`。

## 生命周期

模型中间件允许你挂入你的模型的生命周期事件。支持以下的生命周期事件。

| 方法             | 描述                                 |
| ---------------- | ------------------------------------ |
| `create`         | 在创建一个模型之前运行。             |
| `update`         | 在模型更新前运行。                   |
| `delete(force:)` | 在一个模型被删除之前运行。           |
| `softDelete`     | 在一个模型被软删除之前运行。         |
| `restore`        | 在恢复模型之前运行（与软删除相反）。 |

模型中间件使用`ModelMiddleware`协议来声明。所有的生命周期方法都有一个默认的实现，所以你只需要实现你需要的方法。每个方法都接受有关的模型、对数据库的引用以及链中的下一个动作。中间件可以选择提前返回，抛出一个错误，或者调用下一个动作继续正常进行。

使用这些方法，你可以在特定事件完成之前和之后执行动作。在事件完成后执行动作可以通过映射下一个响应者返回的未来来完成。

```swift
// 将名字大写的中间件示例。
struct PlanetMiddleware: ModelMiddleware {
    func create(model: Planet, on db: Database, next: AnyModelResponder) -> EventLoopFuture<Void> {
        // 模型在创建之前可以在这里进行修改。
        model.name = model.name.capitalized()
        return next.create(model, on: db).map {
            // 一旦行星被创建，这里的代码 
            // 这里将被执行。
            print ("Planet \(model.name) was created")
        }
    }
}
```

一旦你创建了你的中间件，你可以使用`app.databases.middleware`来启用它。

```swift
// 配置模型中间件的例子。
app.databases.middleware.use(PlanetMiddleware(), on: .psql)
```
