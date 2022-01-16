# Leaf概述

Leaf是一种强大的模板语言，具有Swift启发的语法。你可以用它来为前端网站生成动态HTML页面，或者生成丰富的电子邮件，从API中发送。

本指南将给你一个关于Leaf语法和可用标签的概述。

## 模板语法

下面是一个基本的Leaf标签用法的例子。

```leaf
There are #count(users) users.
```

叶子标签是由四个元素组成的。

- Token `#`：这预示着叶子分析器开始寻找一个标签。
- 名称`count`： 这标识了标签。
- 参数列表`(user)`：可以接受零个或多个参数。
- Body：可以使用分号和结尾标签为某些标签提供一个可选的主体。

根据标签的实现，这四个元素可以有许多不同的用法。让我们看看几个例子，看看如何使用Leaf的内置标签：

```leaf
#(variable)
#extend("template"): I'm added to a base template! #endextend
#export("title"): Welcome to Vapor #endexport
#import("body")
#count(friends)
#for(friend in friends): <li>#(friend.name)</li> #endfor
```

Leaf还支持许多你在Swift中熟悉的表达方式。

- `+`
- `%`
- `>`
- `==`
- `||`
- 等等..

```leaf
#if(1 + 1 == 2):
    Hello!
#endif

#if(index % 2 == 0):
    This is even index.
#else:
    This is odd index.
#endif
```

## 上下文

在[入门](./getting-started.md)的例子中，我们用一个`[String: String]`字典来向Leaf传递数据。然而，你可以传递任何符合`Encodable`的东西。实际上，由于不支持`[String: Any]`，所以最好使用`Encodable`结构。这意味着你*不能*传入一个数组，而应该把它包在一个结构中。

```swift
struct WelcomeContext: Encodable {
    var title: String
    var numbers: [Int]
}
return req.view.render("home", WelcomeContext(title: "Hello!", numbers: [42, 9001]))
```

这将向我们的Leaf模板暴露`title`和`numbers`，然后可以在标签中使用。比如说：

```leaf
<h1>#(title)</h1>
#for(number in numbers):
    <p>#(number)</p>
#endfor
```

## 用法

以下是一些常见的叶子的使用例子。

### 条件

Leaf能够使用它的`#if`标签评估一系列的条件。例如，如果你提供一个变量，它将检查该变量在其上下文中是否存在：

```leaf
#if(title):
    The title is #(title)
#else:
    No title was provided.
#endif
```

你也可以写比较，比如说：

```leaf
#if(title == "Welcome"):
    This is a friendly web page.
#else:
    No strangers allowed!
#endif
```

如果你想使用另一个标签作为条件的一部分，你应该省略内部标签的`#`。比如说：

```leaf
#if(count(users) > 0):
    You have users!
#else:
    There are no users yet :(
#endif
```

你也可以使用`#elseif`语句：

```leaf
#if(title == "Welcome"):
    Hello new user!
#elseif(title == "Welcome back!"):
    Hello old user
#else:
    Unexpected page!
#endif
```

### 循环

如果你提供了一个项目数组，Leaf可以在这些项目上循环，让你使用其`#for`标签单独操作每个项目。

例如，我们可以更新我们的Swift代码，以提供一个行星的列表：

```swift
struct SolarSystem: Codable {
    let planets = ["Venus", "Earth", "Mars"]
}

return req.view.render("solarSystem", SolarSystem())
```

然后我们可以像这样在Leaf中对它们进行循环：

```leaf
Planets:
<ul>
#for(planet in planets):
    <li>#(planet)</li>
#endfor
</ul>
```

这将呈现一个看起来像这样的视图：

```
Planets:
- Venus
- Earth
- Mars
```

### 扩展模板

Leaf的`#extend`标签允许你将一个模板的内容复制到另一个模板中。当使用它时，你应该总是省略模板文件的.leaf扩展名。

扩展对于复制一个标准的内容是很有用的，例如一个页面的页脚、广告代码或多个页面共享的表格：

```leaf
#extend("footer")
```

这个标签对于在另一个模板上构建一个模板也很有用。例如，你可能有一个layout.leaf文件，其中包括布置网站所需的所有代码--HTML结构、CSS和JavaScript--有一些空隙，代表页面内容的变化。

使用这种方法，你将构建一个子模板，填入其独特的内容，然后扩展父模板，适当地放置内容。要做到这一点，你可以使用`#export`和`#import`标签来存储和以后从上下文中检索内容。

例如，你可以创建一个`child.leaf`模板，像这样：

```leaf
#extend("master"):
    #export("body"):
        <p>Welcome to Vapor!</p>
    #endexport
#endextend
```

我们调用`#export`来存储一些HTML，并将其提供给我们目前正在扩展的模板。然后我们渲染`master.leaf`，并在需要时使用导出的数据，以及从Swift传入的任何其他上下文变量。例如，`master.leaf`可能看起来像这样：

```leaf
<html>
    <head>
        <title>#(title)</title>
    </head>
    <body>#import("body")</body>
</html>
```

这里我们使用`#import`来获取传递给`#extend`标签的内容。当从Swift传来`["title": "Hi there!"]`时，`child.leaf`将呈现如下：

```html
<html>
    <head>
        <title>Hi there!</title>
    </head>
    <body><p>Welcome to Vapor!</p></body>
</html>
```

###其他标签

#### `#count`

`#count`标签返回一个数组中的个数。比如说：

```leaf
Your search matched #count(matches) pages.
```

#### `#lowercased`

`#lowercased`标签将一个字符串中的所有字母变小写。

```leaf
#lowercased(name)
```

#### `#uppercased`

`#uppercased`标签将一个字符串中的所有字母变大写。

```leaf
#uppercased(name)
```

#### `#capitalized`

`#capitalized`标签将字符串中每个词的第一个字母大写，其他字母小写。参见[`String.capitalized`](https://developer.apple.com/documentation/foundation/nsstring/1416784-capitalized)以了解更多信息。

```leaf
#capitalized(name)
```

#### `#contains`

`#contains`标签接受一个数组和一个值作为其两个参数，如果参数一中的数组包含参数二中的值，则返回true。

```leaf
#if(contains(planets, "Earth")):
    Earth is here!
#else:
    Earth is not in this array.
#endif
```

#### `#date`

`#date`标签将日期转换成可读的字符串。默认情况下，它使用ISO8601格式。

```swift
render(..., ["now": Date()])
```

```leaf
The time is #date(now)
```

你可以传递一个自定义的日期格式化字符串作为第二个参数。参见Swift的[`DateFormatter`](https://developer.apple.com/documentation/foundation/dateformatter)以获得更多信息。

```leaf
The date is #date(now, "yyyy-MM-dd")
```

#### `#unsafeHTML`

`#unsafeHTML`标签的作用类似于一个变量标签--例如`#(变量)`。然而，它并不转义任何`variable`可能包含的HTML：

```leaf
The time is #unsafeHTML(styledTitle)
```

!!! note 
    在使用这个标签时，你应该小心，以确保你提供的变量不会使你的用户受到XSS攻击。
