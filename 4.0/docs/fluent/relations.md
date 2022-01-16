# 关系

Fluent的[模型API](model.md)帮助你通过关系创建和维护模型之间的引用。支持两种类型的关系。

- [父级](#parent)/[可选子级](#optional-child) (一对一)
- [父级](#parent)/[子级](#children) (一对多)
- [同级](#同级) (多对多)

## 父级

`@Parent`关系存储对另一个模型的`@ID`属性的引用。

```swift
final class Planet: Model {
    // 父级关系的例子。
    @Parent(key: "star_id")
    var star: Star
}
```

`@Parent`包含一个名为`id`的`@Field`，用于设置和更新关系。

```swift
// 设置父级关系ID
earth.$star.id = sun.id
```

例如，`Planet`的初始化器看起来像：

```swift
init(name: String, starID: Star.IDValue) {
    self.name = name
    // ...
    self.$star.id = starID
}
```

`key`参数定义了用于存储父类标识符的字段键。假设`Star`有一个`UID`标识符，这个`@Parent`关系与下面的[字段定义](schema.md#field)兼容。

```swift
.field("star_id", .uuid, .required, .references("star", "id"))
```

注意，[`.references`](schema.md#field-constraint)约束是可选的。更多信息请参见[schema](schema.md)。

### 可选父级

`@OptionalParent`关系存储对另一个模型的`@ID`属性的可选引用。它的工作原理与`@Parent`类似，但允许关系为`nil`。

```swift
final class Planet: Model {
    // 可选的父级关系的例子。
    @OptionalParent(key: "star_id")
    var star: Star?
}
```

这个字段的定义与`@Parent`类似，除了`.required`约束应该被省略。

```swift
.field("star_id", .uuid, .references("star", "id"))
```

## 可选子级

`@OptionalChild`属性在两个模型之间创建一个一对一的关系。它不在根模型上存储任何值。

```swift
final class Planet: Model {
    // 可选子级关系的例子。
    @OptionalChild(for: \.$planet)
    var governor: Governor?
}
```

`for`参数接受一个指向引用根模型的`@Parent`或`@OptionalParent`关系的关键路径。

一个新的模型可以通过`create'方法被添加到这个关系中。

```swift
// 向一个关系添加新模型的例子。
let jane = Governor(name: "Jane Doe")
try await mars.$governor.create(jane, on: database)
```

这将自动在子模型上设置父级ID。

由于这个关系不存储任何值，根模型不需要数据库模式条目。

关系的一对一性质应该在子模型的模式中使用引用父类模型的列上的`.unique`约束来强制执行。

```swift
try await database.schema(Governor.schema)
    .id()
    .field("name", .string, .required)
    .field("planet_id", .uuid, .required, .references("planets", "id"))
    // unique约束的例子
    .unique(on: "planet_id")
    .create()
```
!!! warning
    从客户的模式中省略对父级ID字段的唯一性约束会导致不可预测的结果。
    如果没有唯一性约束，子表可能最终为任何给定的父类表包含一个以上的子行；在这种情况下，`@OptionalChild`属性仍然一次只能访问一个子，没有办法控制哪个子被加载。如果你可能需要为任何给定的父类存储多个子行，请使用`@Children`代替。

## 子级

`@Children`属性在两个模型之间创建一个一对多的关系。它不在根模型上存储任何值。

```swift
final class Star: Model {
    // 子级关系的例子。
    @Children(for: \.$star)
    var planets: [Planet]
}
```

`for`参数接受一个指向引用根模型的`@Parent`或`@OptionalParent`关系的关键路径。在这种情况下，我们引用的是前面[例子](#父级)中的`@Parent`关系。

新的模型可以使用`create`方法被添加到这个关系中。

```swift
// 向一个关系添加新模型的例子。
let earth = Planet(name: "Earth")
try await sun.$planets.create(earth, on: database)
```

这将自动在子模型上设置父类ID。

因为这种关系不存储任何值，所以不需要数据库模式条目。

## 同级

`@Siblings`属性在两个模型之间创建了一个多对多的关系。它通过一个叫做pivot的三级模型来实现。

让我们看一下`Planet`和`Tag`之间的多对多关系的例子。

```swift
// Pivot模型的例子。
final class PlanetTag: Model {
    static let schema = "planet+tag"
    
    @ID(key: .id)
    var id: UUID?

    @Parent(key: "planet_id")
    var planet: Planet

    @Parent(key: "tag_id")
    var tag: Tag

    init() { }

    init(id: UUID? = nil, planet: Planet, tag: Tag) throws {
        self.id = id
        self.$planet.id = try planet.requireID()
        self.$tag.id = try tag.requireID()
    }
}
```

pivot是包含两个`@Parent`关系的正常模型。每个模型都有一个被关联。如果需要的话，额外的属性可以被存储在pivot上。

给pivot模型添加一个 [unique](schema.md#unique) 约束可以帮助防止多余的条目。参见[schema](schema.md)以了解更多信息。

```swift
// 不允许重复的关系。
.unique(on: "planet_id", "tag_id")
```

一旦pivot被创建，使用`@Siblings`属性来创建关系。

```swift
final class Planet: Model {
    // 同级关系的例子。
    @Siblings(through: PlanetTag.self, from: \.$planet, to: \.$tag)
    public var tags: [Tag]
}
```

`@Siblings`属性需要三个参数。

- `through`: pivot模型的类型。
- `from`: 从pivot到引用根模型的父类关系的关键路径。
- `to`: 从pivot到引用相关模型的父类关系的关键路径。

相关模型上的反向`@Siblings`属性完成了该关系。

```swift
final class Tag: Model {
    // 同级关系的例子。
    @Siblings(through: PlanetTag.self, from: \.$tag, to: \.$planet)
    public var planets: [Planet]
}
```

### 同级的附件

`@Siblings`属性有从关系中添加和删除模型的方法。

使用`attach`方法来添加一个模型到关系中。这将自动创建并保存pivot模型。

```swift
let earth: Planet = ...
let inhabited: Tag = ...
// 将模型添加到关系中。
try await earth.$tags.attach(inhabited, on: database)
```

当附加一个单一的模型时，你可以使用`method`参数来选择在保存前是否要检查关系。

```swift
// 只在关系不存在的情况下附加。
try await earth.$tags.attach(inhabited, method: .ifNotExists, on: database)
```

使用`detach`方法从关系中删除一个模型。这将删除相应的pivot模型。

```swift
// 将模型从关系中移除。
try await earth.$tags.detach(inhabited, on: database)
```

你可以使用`isAttached`方法检查一个模型是否相关。

```swift
// 检查这些模型是否相关。
earth.$tags.isAttached(to: inhabited)
```

## 获取

使用`get(on:)`方法来获取一个关系的值。

```swift
// 获取太阳系的所有行星。
sun.$planets.get(on: database).map { planets in
    print(planets)
}

// 或者

let planets = try await sun.$planets.get(on: database)
print(planets)
```

使用`reload`参数来选择是否应该从数据库中重新获取关系，如果它已经被加载。

```swift
try await sun.$planets.get(reload: true, on: database)
```

## 查询

在一个关系上使用`query(on:)`方法，为相关模型创建一个查询生成器。

```swift
// 取出所有命名以M开头的太阳行星。
try await sun.$planets.query(on: database).filter(\.$name =~ "M").all()
```

更多信息见[query](query.md)。

## 急于加载

Fluent的查询生成器允许你在从数据库中获取模型的关系时预先加载。这被称为急于加载，允许你同步访问关系，而不需要先调用[`load`](#lazy-eager-loading)或[`get`](#get)。

要急于加载一个关系，需要将关系的关键路径传递给查询生成器的`with`方法。

```swift
// 急于加载的例子。
Planet.query(on: database).with(\.$star).all().map { planets in
    for planet in planets {
        // `star`在这里可以同步访问。
        // 因为它已经被急于加载。
        print(planet.star.name)
    }
}

// 或者

let planets = try await Planet.query(on: database).with(\.$star).all()
for planet in planets {
    // `star`在这里可以同步访问。
    // 因为它已经被急于加载。
    print(planet.star.name)
}
```

在上面的例子中，一个名为 `star`的[`@Parent`](#父级)关系的关键路径被传递给`with`。这导致查询生成器在所有行星被加载后进行额外的查询，以获取所有相关的恒星。然后，这些星星可以通过`@Parent`属性同步访问。

每一个急于加载的关系只需要一个额外的查询，无论返回多少个模型。急切加载只能通过查询生成器的`all`和`first`方法实现。


### 嵌套急于加载

查询生成器的`with`方法允许你在被查询的模型上急于加载关系。然而，你也可以在相关模型上急于加载关系。

```swift
let planets = try await Planet.query(on: database).with(\.$star) { star in
    star.with(\.$galaxy)
}.all()
for planet in planets {
    // `star.galaxy`可以在这里同步访问。
    // 因为它已经被急于加载。
    print(planet.star.galaxy.name)
}
```

`with`方法接受一个可选的闭包作为第二个参数。这个闭包接受所选关系的急迫加载构建器。渴望加载的深度没有限制，可以嵌套。

## 懒惰的急于加载

如果你已经获取了父类模型，你想加载它的一个关系，你可以使用`load(on:)`方法来达到这个目的。这将从数据库中获取相关模型，并允许它作为一个本地属性被访问。

```swift
planet.$star.load(on: database).map {
    print(planet.star.name)
}

// 或者

try await planet.$star.load(on: database)
print(planet.star.name)
```

要检查一个关系是否已经被加载，使用`value`属性。

```swift
if planet.$star.value != nil {
    // 关系已被加载。
    print(planet.star.name)
} else {
    // 关系没有被加载。
    // 试图访问planet.star将失败。
}
```

如果你在一个变量中已经有了相关的模型，你可以使用上面提到的`value`属性手动设置关系。

```swift
planet.$star.value = star
```

这将把相关模型附加到父类模型上，就像它被急于加载或懒于加载一样，不需要额外的数据库查询。
