# Leaf

Leaf是一种强大的模板语言，具有Swift启发的语法。你可以用它来生成前端网站的动态HTML页面，或者生成丰富的电子邮件，从API中发送。

## Package

使用Leaf的第一步是在你的SPM包清单文件中把它作为一个依赖项添加到你的项目中。

```swift
// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "MyApp",
    platforms: [
       .macOS(.v10_15)
    ],
    dependencies: [
        /// 任何其他的依赖性...
        .package(url: "https://github.com/vapor/leaf.git", from: "4.0.0"),
    ],
    targets: [
        .target(name: "App", dependencies: [
            .product(name: "Leaf", package: "leaf"),
        /// 任何其他的依赖性...
        ]),
        // 其他目标
    ]
)
```

## 配置

一旦你将软件包添加到你的项目中，你可以配置Vapor来使用它。这通常是在[`configure.swift`](.../folder-structure.md#configureswift)中完成的。

```swift
import Leaf

app.views.use(.leaf)
```

这告诉Vapor在你的代码中调用`req.view`时使用`LeafRenderer`。

!!! note
    Leaf有一个内部缓存用于渲染页面。当`Application`的环境被设置为`.development`时，这个缓存被禁用，所以对模板的修改会立即生效。在`.production`和所有其他环境下，缓存默认是启用的；任何对模板的修改都将不会生效，直到应用程序重新启动。

!!! warning
    为了使Leaf在从Xcode运行时能够找到模板，你必须为你的Xcode工作区设置[自定义工作目录](https://docs.vapor.codes/4.0/xcode/#custom-working-directory)。

## 文件夹结构

一旦你配置了Leaf，你将需要确保你有一个`Views`文件夹来存储你的`.leaf`文件。默认情况下，Leaf希望视图文件夹是相对于项目根目录的`./Resources/Views`。

如果你打算为Javascript和CSS文件提供服务，你可能还想启用Vapor的[`FileMiddleware`](https://api.vapor.codes/vapor/latest/Vapor/Classes/FileMiddleware.html)，从`/Public`文件夹中提供文件。

```
VaporApp
├── Package.swift
├── Resources
│   ├── Views
│   │   └── hello.leaf
├── Public
│   ├── images (images resources)
│   ├── styles (css resources)
└── Sources
    └── ...
```

## 渲染一个视图

现在Leaf已经配置好了，让我们来渲染你的第一个模板。在`Resources/Views`文件夹中，创建一个名为`hello.leaf`的新文件，内容如下。

```leaf
Hello, #(name)!
```

然后，注册一个路由（通常在`routes.swift`或控制器中完成）来渲染视图。

```swift
app.get("hello") { req -> EventLoopFuture<View> in
    return req.view.render("hello", ["name": "Leaf"])
}

// 或

app.get("hello") { req async throws -> View in
    return try await req.view.render("hello", ["name": "Leaf"])
}
```

这使用了`Request`上的通用`view`属性，而不是直接调用Leaf。这允许你在测试中切换到一个不同的渲染器。


打开你的浏览器，访问`/hello`。你应该看到`Hello, Leaf!`。恭喜你渲染了你的第一个Leaf视图!
