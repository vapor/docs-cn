# 自定义标签

你可以使用[`LeafTag`](https://api.vapor.codes/leaf-kit/latest/LeafKit/LeafSyntax/LeafTag.html)协议创建自定义Leaf标签。

为了证明这一点，让我们来看看创建一个自定义标签`#now`，打印出当前的时间戳。该标签还将支持一个用于指定日期格式的可选参数。

## LeafTag

首先创建一个名为`NowTag`的类，并将其与`LeafTag`相匹配。

```swift
struct NowTag: LeafTag {
    
    func render(_ ctx: LeafContext) throws -> LeafData {
        ...
    }
}
```

现在我们来实现`render(_:)`方法。传递给这个方法的`LeafContext`上下文有我们应该需要的一切。

```swift
struct NowTagError: Error {}

let formatter = DateFormatter()
switch ctx.parameters.count {
case 0: formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
case 1:
    guard let string = ctx.parameters[0].string else {
        throw NowTagError()
    }
    formatter.dateFormat = string
default:
    throw NowTagError()
}

let dateAsString = formatter.string(from: Date())
return LeafData.string(dateAsString)
```

!!! tip
    如果你的自定义标签渲染了HTML，你应该将你的自定义标签符合`UnsafeUnescapedLeafTag`，这样HTML就不会被转义。记住要检查或净化任何用户输入。

## 配置标签

现在我们已经实现了`NowTag`，我们只需要把它告诉Leaf。你可以像这样添加任何标签--即使它们来自一个单独的包。你通常在`configure.swift`中这样做：

```swift
app.leaf.tags["now"] = NowTag()
```

就这样了! 我们现在可以在Leaf中使用我们的自定义标签。

```leaf
The time is #now()
```

## 上下文属性

`LeafContext`包含两个重要的属性。`parameters`和`data`，它们拥有我们应该需要的一切。

- `parameters`: 一个数组，包含标签的参数。
- `data`: 一个字典，包含传递给`render(_:_:)`的视图的数据，作为上下文。

### 示例 Hello 标签

为了了解如何使用它，让我们使用这两个属性实现一个简单的Hello标签。

#### 使用参数

我们可以访问包含名称的第一个参数。

```swift
struct HelloTagError: Error {}

public func render(_ ctx: LeafContext) throws -> LeafData {

        guard let name = ctx.parameters[0].string else {
            throw HelloTagError()
        }

        return LeafData.string("<p>Hello \(name)</p>'")
    }
}
```

```leaf
#hello("John")
```

#### 使用数据

我们可以通过使用data属性中的"name"键来访问name值。

```swift
struct HelloTagError: Error {}

public func render(_ ctx: LeafContext) throws -> LeafData {

        guard let name = ctx.data["name"]?.string else {
            throw HelloTagError()
        }

        return LeafData.string("<p>Hello \(name)</p>'")
    }
}
```

```leaf
#hello()
```

控制器:

```swift
return req.view.render("home", ["name": "John"])
```
