# 查询

Fluent的查询API允许你从数据库中创建、读取、更新和删除模型。它支持过滤结果、连接、分块、聚合等功能。

```swift
// Fluent的查询API的一个例子。
let planets = Planet.query(on: database)
    .filter(\.$type == .gasGiant)
    .sort(by: \.$name)
    .with(\.$star)
    .all()
```

查询构建器与单一的模型类型相联系，可以使用静态[`query`](model.md#查询)方法来创建。它们也可以通过将模型类型传递给数据库对象的`query`方法来创建。

```swift
// 也可以创建一个查询生成器。
database.query(Planet.self)
```

## 所有

`all()`方法返回一个模型的数组。

```swift
// 获取所有行星。
let planets = Planet.query(on: database).all()
```

`all`方法也支持从结果集中只取一个字段。

```swift
//获取所有的星球名称。
let names = Planet.query(on: database).all(\.$name)
```

### 第一

`first()`方法返回一个单一的、可选的模型。如果查询的结果有一个以上的模型，只返回第一个。如果查询没有结果，`nil`将被返回。

```swift
// 获取第一个名为Earth的行星。
let earth = Planet.query(on: database)
    .filter(\.$name == "Earth")
    .first()
```

!!!提示
    这个方法可以和[`unwrap(or:)`](.../basics/errors.md#abort)结合起来，返回一个非选择的模型或抛出一个错误。

## 过滤器

`Filter`方法允许你限制包含在结果集中的模型。这个方法有几个重载。

###价值过滤器

最常用的`filter`方法接受一个带有数值的操作表达式。

```swift
// 一个字段值过滤的例子。
Planet.query(on: database).filter(\.$type == .gasGiant)
```

这些运算符表达式在左边接受一个字段关键路径，在右边接受一个值。提供的值必须与字段的预期值类型相匹配，并被绑定到结果查询中。过滤表达式是强类型的，允许使用前导点语法。

下面是所有支持的值运算符的列表。

|运算符|描述|
|-|-|
|`==`|等于。|
|`!=`|不等于。|
|`>=`|大于或等于。|
|`>`|大于。|
|`<`|少于。|
|`<=`|小于或等于。|

### 字段过滤

`filter`方法支持比较两个字段。

```swift
// 所有具有相同firstName和lastName的用户。
User.query(on: database)
    .filter(\.$firstName == \.$lastName)
```

字段过滤器支持与[值过滤器](#值-过滤器)相同的操作。

### 子集过滤器

`filter`方法支持检查一个字段的值是否存在于一个给定的值集合中。

```swift
// 所有具有gasGiant或smallRocky的行星。
Planet.query(on: database)
    .filter(\.$type ~~ [.gasGiant, .smallRocky])
```

提供的值集可以是任何Swift `Collection`，其`Element`类型与字段的值类型相符。

下面是所有支持的子集运算符的列表。

|运算符|描述|
|-|-|
|`~~`|值在集合中。|
|`!~`|值不在集合中。|

### 包含过滤器

`filter`方法支持检查一个字符串字段的值是否包含一个给定的子字符串。

```swift
// 所有名字以字母M开头的行星
Planet.query(on: database)
    .filter(\.$name =~ "M")
```

这些运算符只适用于有字符串值的字段。

下面是所有支持的包含运算符的列表。

|运算符|描述|
|-|-|
|`~~`|包含子字符串。|
|`!~`|不包含子字符串|
|`=~`|与前缀相匹配。|
|`!=~`|与前缀不匹配。|
|`~=`|匹配后缀。|
|`!~=`|与后缀不匹配。|

### 组

默认情况下，添加到查询中的所有过滤器都需要匹配。查询生成器支持创建一个过滤器组，其中只有一个过滤器必须匹配。

```swift
// 所有名称为Earth或Mars的行星
Planet.query(on: database).group(.or) { group in
    group.filter(\.$name == "Earth").filter(\.$name == "Mars")
}
```

`Group`方法支持通过`and`或`or`逻辑组合过滤器。这些组可以无限制地嵌套。顶层的过滤器可以被认为是在一个`and`组中。

## 聚合

查询生成器支持几种对一组数值进行计算的方法，如计数或平均。

```swift
// 数据库中行星的数量。
Planet.query(on: database).count()
```

除了`count`以外的所有聚合方法都需要传递一个字段的关键路径。

```swift
//按字母顺序排序的最低名称。
Planet.query(on: database).min(\.$name)
```

下面是所有可用的聚合方法的列表。

|汇总|描述|
|-|-|
|`count`|结果的数量。|
|`sum`|结果值的总和。|
|`average`|结果值的平均值。|
|`min`|最小结果值。|
|`max`|最大的结果值。|

除了`count`之外，所有的聚合方法都将字段的值类型作为结果返回。`count`总是返回一个整数。

## Chunk

查询生成器支持将结果集作为独立的块返回。这有助于你在处理大型数据库读取时控制内存的使用。

```swift
// 每次最多提取64个分块的所有计划。
Planet.query(on: self.database).chunk(max: 64) { planets in
    // Handle chunk of planets.
}
```

根据结果的总数，提供的闭包将被调用0次或多次。返回的每一项都是一个`Result`，包含模型或试图解码数据库条目时返回的一个错误。

## 字段

默认情况下，一个模型的所有字段都将通过查询从数据库中读取。你可以选择使用`field`方法只选择模型字段的一个子集。

```swift
// 只选择星球的id和name字段
Planet.query(on: database)
    .field(\.$id).field(\.$name)
    .all()
```

任何在查询过程中没有被选中的模型字段都将处于单元化状态。试图直接访问未初始化的字段将导致一个致命的错误。要检查一个模型的字段值是否被设置，使用`value`属性。

```swift
if let name = planet.$name.value {
    // 名字被取走了。
} else {
    // 名字没有被取走。
    // 访问`planet.name`将失败。
}
```

## 独特

查询生成器的`unique`方法只返回不同的结果（没有重复的）。

```swift
// 返回所有唯一的用户名字。
User.query(on: database).unique().all(\.$firstName)
```

`unique`在用`all`获取单个字段时特别有用。然而，你也可以使用[`field`](#field)方法选择多个字段。由于模型标识符总是唯一的，你应该在使用`unique`时避免选择它们。

## 范围

查询生成器的`range`方法允许你使用Swift范围来选择结果的一个子集。

```swift
// 取出前5个行星。
Planet.query(on: self.database)
    .range(..<5)
```

范围值是无符号整数，从零开始。了解更多关于[Swift ranges](https://developer.apple.com/documentation/swift/range)。

```swift
// 跳过前两个结果。
.range(2...)
```

## 联合

查询生成器的`join`方法允许你在你的结果集中包括另一个模型的字段。多于一个模型可以被加入到你的查询中。

```swift
// 获取所有有太阳系的行星。
Planet.query(on: database)
    .join(Star.self, on: \Planet.$star.$id == \Star.$id)
    .filter(Star.self, \.$name == "Sun")
    .all()
```

参数`on `接受两个字段之间的相等表达式。其中一个字段必须已经存在于当前的结果集中。另一个字段必须存在于被连接的模型中。这些字段必须有相同的值类型。

大多数查询生成器方法，如`filter`和`sort`，支持联合模型。如果一个方法支持联合模型，它将接受联合模型类型作为第一个参数。

```swift
// 在Star模型上按连接字段 "name "排序。
.sort(Star.self, \.$name)
```

使用连接的查询仍然会返回一个基础模型的数组。要访问连接的模型，请使用`joined`方法。

```swift
// 从查询结果中访问连接的模型。
let planet: Planet = ...
let star = try planet.joined(Star.self)
```

### 模型别名

模型别名允许你将同一个模型多次加入到一个查询中。要声明一个模型别名，创建一个或多个符合`ModelAlias`的类型。

```swift
// 模型别名的例子。
final class HomeTeam: ModelAlias {
    static let name = "home_teams"
    let model = Team()
}
final class AwayTeam: ModelAlias {
    static let name = "away_teams"
    let model = Team()
}
```

这些类型通过`model`属性引用被别名的模型。一旦创建，你可以在查询生成器中像普通模型一样使用模型别名。

```swift
// 获取所有主队名称为Vapor的比赛
// 的所有比赛，并按照客队的名字进行排序。
let matches = try Match.query(on: self.database)
    .join(HomeTeam.self, on: \Match.$homeTeam.$id == \HomeTeam.$id)
    .join(AwayTeam.self, on: \Match.$awayTeam.$id == \AwayTeam.$id)
    .filter(HomeTeam.self, \.$name == "Vapor")
    .sort(AwayTeam.self, \.$name)
    .all().wait()
```

所有的模型字段都可以通过`@dynamicMemberLookup`的模型别名类型访问。

```swift
// 从结果中访问加入的模型。
let home = try match.joined(HomeTeam.self)
print(home.name)
```

## 更新

查询生成器支持使用`update`方法一次更新多个模型。

```swift
// 更新所有名为"Earth"的行星
Planet.query(on: database)
    .set(\.$type, to: .dwarf)
    .filter(\.$name == "Pluto")
    .update()
```

`update`支持`set`, `filter`, 和`range`方法。

## 删除

查询生成器支持使用`delete`方法一次删除一个以上的模型.

```swift
// 删除所有名为"Vulcan"的行星
Planet.query(on: database)
    .filter(\.$name == "Vulcan")
    .delete()
```

`delete`支持`filter`方法。

## 分页

Fluent的查询API支持使用`paginate`方法对结果进行自动分页。

```swift
// 基于请求的分页的例子.
app.get("planets") { req in
    Planet.query(on: req.db).paginate(for: req)
}
```

`paginate(for:)`方法将使用请求URI中的`page`和`per`参数来返回所需的结果集。关于当前页面和结果总数的元数据被包含在`metadata`键中。

```http
GET /planets?page=2&per=5 HTTP/1.1
```

上述请求将产生一个结构如下的响应。

```json
{
    "items": [...],
    "metadata": {
        "page": 2,
        "per": 5,
        "total": 8
    }
}
```

页码从`1`开始。你也可以进行手动的页面请求。

```swift
// 手动分页的例子。
.paginate(PageRequest(page: 1, per: 2))
```

## 排序

查询结果可以使用`sort`方法按字段值进行排序。

```swift
// 取出按名称排序的行星。
Planet.query(on: database).sort(\.$name)
```

在出现相同的情况下，可以添加额外的排序作为后备排序。回调将按照它们被添加到查询生成器的顺序使用。

```swift
// 取出按名字排序的用户。如果两个用户有相同的名字，按年龄排序。
User.query(on: database).sort(\.$name).sort(\.$age)
```
