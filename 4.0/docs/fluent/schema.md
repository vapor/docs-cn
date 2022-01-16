# 模式

Fluent的模式API允许你以编程方式创建和更新你的数据库模式。它通常与[migrate](migration.md)一起使用，以便为[model](model.md)的使用准备数据库。

```swift
// Fluent的模式API的一个例子
try await database.schema("planets")
    .id()
    .field("name", .string, .required)
    .field("star_id", .uuid, .required, .references("stars", "id"))
    .create()
```

要创建一个`SchemaBuilder`，使用数据库的`schema`方法。传入你想影响的表或集合的名称。如果你正在编辑一个模型的模式，确保这个名字与模型的[`schema`](model.md#schema)相符。

## 行动

模式API支持创建、更新和删除模式。每个动作都支持API的一个可用方法的子集。

### 创建

调用`create()`在数据库中创建一个新的表或集合。所有用于定义新字段和约束的方法都被支持。更新或删除的方法被忽略。

```swift
// 一个创建模式的例子。
try await database.schema("planets")
    .id()
    .field("name", .string, .required)
    .create()
```

如果一个具有所选名称的表或集合已经存在，将抛出一个错误。要忽略这一点，请使用`.ignoreExisting()`。

### 更新

调用`update()`可以更新数据库中现有的表或集合。所有用于创建、更新和删除字段和约束的方法都被支持。

```swift
// 一个模式更新的例子。
try await database.schema("planets")
    .unique(on: "name")
    .deleteField("star_id")
    .update()
```

### 删除

调用`delete()`可以从数据库中删除一个现有的表或集合。没有额外的方法被支持。

```swift
// 一个删除模式的例子.
database.schema("planets").delete()
```

## 字段

在创建或更新模式时，可以添加字段。

```swift
// 添加一个新的字段
.field("name", .string, .required)
```

第一个参数是字段的名称。这应该与相关模型属性上使用的键相匹配。第二个参数是字段的[数据类型](#data-type)。最后，可以添加零个或多个[约束](#field-constraint)。

### 数据类型

支持的字段数据类型列举如下。

|数据类型|快速类型|
|-|-|
|`.string`|`String`|
|`.int{8,16,32,64}`|`Int{8,16,32,64}`|
|`.uint{8,16,32,64}`|`UInt{8,16,32,64}`|
|`.bool`|`Bool`|
|`.datetime`|`Date` (推荐)|
|`.time`|`Date` (省略日、月、年)|
|`.date`|`Date` (省略一天中的时间)|
|`.float`|`Float`|
|`.double`|`Double`|
|`.data`|`Data`|
|`.uuid`|`UUID`|
|`.dictionary`|看 [dictionary](#dictionary)|
|`.array`|看 [array](#array)|
|`.enum`|看 [enum](#enum)|

### 字段约束

支持的字段约束列举如下。

|字段约束|描述|
|-|-|
|`.required`|不允许使用`nil`值。|
|`.references`|要求这个字段的值与被引用模式中的一个值相匹配。参见[外键](#foreign-key)|
|`.identifier`|表示主键。参见[标识符](#identifier)|

### 标识符

如果你的模型使用一个标准的`@ID`属性，你可以使用`id()`助手来创建它的字段。这使用了特殊的`.id`字段键和`UUID`值类型。

```swift
// 添加默认标识符的字段。
.id()
```

对于自定义标识符类型，你将需要手动指定该字段。

```swift
// 添加自定义标识符的字段。
.field("id", .int, .identifier(auto: true))
```

`identifier`约束可以用在一个字段上，表示主键。`auto`标志决定了数据库是否应该自动生成这个值。

### 更新字段

你可以使用`updateField`来更新一个字段的数据类型。

```swift
// 将字段更新为`double`数据类型。
.updateField("age", .double)
```

参见[advanced](advanced.md#sql)了解更多关于高级模式更新的信息。

### 删除字段

你可以使用`deleteField`从模式中删除一个字段。

```swift
// 删除字段"age"。
.deleteField("age")
```

## 制约因素

在创建或更新模式时，可以添加约束条件。与[字段约束](#field-constraint)不同，顶层约束可以影响多个字段。

### 唯一

唯一约束要求在一个或多个字段中不存在重复的值。

```swift
// 不允许重复的电子邮件地址。
.unique(on: "email")
```

如果多个字段被限制，每个字段的具体组合值必须是唯一的。

```swift
// 不允许有相同全名的用户。
.unique(on: "first_name", "last_name")
```

要删除一个唯一约束，使用`deleteUnique`。

```swift
// 删除重复的电子邮件约束。
.deleteUnique(on: "email")
```

### 约束条件名称

Fluent默认会生成唯一的约束名称。然而，你可能想传递一个自定义的约束名称。你可以使用`name`参数来做到这一点。

```swift
// 不允许重复的电子邮件地址。
.unique(on: "email", name: "no_duplicate_emails")
```

要删除一个命名的约束，你必须使用`deleteConstraint(name:)`。

```swift
// 删除重复的电子邮件约束。
.deleteConstraint(name: "no_duplicate_emails")
```

## 外键

外键约束要求一个字段的值与被引用字段中的一个值相匹配。这对于防止无效的数据被保存是很有用的。外键约束可以作为字段或顶层约束来添加。

要给一个字段添加外键约束，使用`.references`。

```swift
// 添加字段外键约束的例子。
.field("star_id", .uuid, .required, .references("stars", "id"))
```

上述约束要求`star_id`字段中的所有值必须与Star的`id`字段中的一个值匹配。

同样的约束可以使用`foreignKey`作为顶层约束来添加。

```swift
// 添加顶层外键约束的例子。
.foreignKey("star_id", references: "stars", "id")
```

与字段约束不同，顶层约束可以在模式更新中被添加。它们也可以被[命名](#constraint-name)。

外键约束支持可选的`onDelete`和`onUpdate`动作。

|外键动作|描述|
|-|-|
|`.noAction`|防止违反外键（默认）。|
|`.restrict`|与`.noAction`相同。|
|`.cascade`|通过外键传播删除信息。|
|`.setNull`|如果引用被破坏，则将字段设置为空。|
|`.setDefault`|如果引用被破坏，将字段设置为默认。|

下面是一个使用外键操作的例子。

```swift
// 添加一个顶层外键约束的例子。
.foreignKey("star_id", references: "stars", "id", onDelete: .cascade)
```

!!!warning
    外键操作只发生在数据库中，绕过了Fluent。
    这意味着像模型中间件和软删除可能无法正常工作。

## Dictionary

dictionary数据类型能够存储嵌套的dictionary值。这包括符合`Codable'的结构和具有`Codable'值的Swift字典。

!!!注意
    Fluent的SQL数据库驱动在JSON列中存储嵌套字典。

以下面这个`Codable`结构为例。

```swift
struct Pet: Codable {
    var name: String
    var age: Int
}
```

由于这个`Pet`结构是`Codable`的，它可以被存储在`@Field`中。

```swift
@Field(key: "pet")
var pet: Pet
```

这个字段可以使用`.dictionary(of:)`数据类型来存储。

```swift
.field("pet", .dictionary, .required)
```

由于`Codable`类型是异质的字典，我们不指定`of`参数。

如果字典的值是同质的，例如`[String: Int]`，`of`参数将指定值的类型。

```swift
.field("numbers", .dictionary(of: .int), .required)
```

字典的键必须始终是字符串。

## 数组

数组数据类型能够存储嵌套数组。这包括包含`Codable`值的Swift数组和使用无键容器的`Codable`类型。

以下面这个存储字符串数组的`@Field`为例。

```swift
@Field(key: "tags")
var tags: [String]
```

这个字段可以使用`.array(of:)`数据类型来存储。

```swift
.field("tags", .array(of: .string), .required)
```

由于数组是同质的，我们指定`of`参数。

可编码的Swift`Array`将总是有一个同质的值类型。将异质值序列化为无键容器的自定义`Codable`类型是个例外，应该使用`.array`数据类型。

## 枚举

枚举数据类型能够在本地存储以字符串为基础的Swift枚举。本地数据库枚举为你的数据库提供了一个额外的类型安全层，并且可能比原始枚举更有性能。

要定义一个本地数据库枚举，请使用`Database`上的`enum`方法。使用`case`来定义枚举的每个情况。

```swift
// 一个创建枚举的例子。
database.enum("planet_type")
    .case("smallRocky")
    .case("gasGiant")
    .case("dwarf")
    .create()
```

一旦创建了一个枚举，你可以使用`read()`方法为你的模式字段生成一个数据类型。

```swift
// 一个读取枚举并使用它来定义一个新字段的例子。
database.enum("planet_type").read().flatMap { planetType in
    database.schema("planets")
        .field("type", planetType, .required)
        .update()
}

// 或

let planetType = try await database.enum("planet_type").read()
try await database.schema("planets")
    .field("type", planetType, .required)
    .update()
```

要更新一个枚举，请调用`update()`。可以从现有的枚举中删除案例。

```swift
// 一个枚举更新的例子。
database.enum("planet_type")
    .deleteCase("gasGiant")
    .update()
```

要删除一个枚举，请调用`delete()`。

```swift
// 一个删除枚举的例子。
database.enum("planet_type").delete()
```

## 模型耦合

模式构建是有目的地与模型解耦的。与查询构建不同，模式构建不使用关键路径，并且是完全字符串类型的。这一点很重要，因为模式定义，特别是那些为迁移而写的定义，可能需要引用不再存在的模型属性。

为了更好地理解这一点，请看下面这个迁移示例。

```swift
struct UserMigration: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("users")
            .field("id", .uuid, .identifier(auto: false))
            .field("name", .string, .required)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("users").delete()
    }
}
```

让我们假设这次迁移已经被推送到生产中了。现在我们假设我们需要对用户模型做如下改变。

```diff
- @Field(key: "name")
- var name: String
+ @Field(key: "first_name")
+ var firstName: String
+
+ @Field(key: "last_name")
+ var lastName: String
```

我们可以通过以下迁移进行必要的数据库模式调整。

```swift
struct UserNameMigration: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("users")
            .deleteField("name")
            .field("first_name", .string)
            .field("last_name", .string)
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema("users").delete()
    }
}
```

请注意，为了使这个迁移工作，我们需要能够同时引用被删除的`name`字段和新的`firstName`和`lastName`字段。此外，原来的`UserMigration`应该继续有效。这一点用密钥路径是不可能做到的。
