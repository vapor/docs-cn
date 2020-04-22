# Swift Package Manager

[Swift Package Manager](https://swift.org/package-manager/)(SPM)用于构建项目的源代码和依赖项。由于 Vapor 严重依赖 SPM，因此最好了解其工作原理。

SPM 与 Cocoapods，Ruby gems 和 NPM 相似。您可以在命令行中将 SPM 与 `swift build`、`swift test` 等命令或兼容的 IDE 结合使用。但是，与其他软件包管理器不同，SPM 软件包没有中央软件包索引。SPM 使用 [Git 标签](https://git-scm.com/book/en/v2/Git-Basics-Tagging) 和 URL 来获取 Git 存储库和依赖版本。

## Package Manifest

SPM 在项目中查找的第一项是 package manifest。它应始终位于项目的根目录中，并命名为"Package.swift"。

看一下这个示例.

```swift
// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "app",
    platforms: [
       .macOS(.v10_15)
    ],
    products: [
        .executable(name: "Run", targets: ["Run"]),
        .library(name: "App", targets: ["App"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
    ],
    targets: [
        .target(name: "App", dependencies: ["Fluent"]),
        .target(name: "Run", dependencies: ["App"]),
        .testTarget(name: "AppTests", dependencies: ["App"])
    ]
)

```

以下各节将说明清单的每个部分。

### Tools Version

第一行表示需要使用的 Swift tools 版本号，它指明了 Swift 的最低可用版本。

### Package Name

`Package` 的第一个参数代表当前 package 的名字。如果软件包是公共的，则应使用Git存储库URL的最后一段作为名称

### Platforms

`platforms` 数组指定此程序包支持的平台。通过指定`.macOS（.v10_14）`，说明此软件包需要 macOS Mojave 或更高版本。 Xcode加载该项目时，它将自动将最低部署版本设置为10.14，以便您可以使用所有可用的 API

### Products

products 字段代表 package 构建的时候要生成的 targets。示例中，有两个 target，一个是 library，另一个是 executable

### Dependencies

dependencies 字段代表需要依赖的 SPM package。所有 Vapor 应用都依赖于 Vapor package ，但是你也可以添加其它想要的 dependency。

上面这个示例可见，[vapor/vapor](https://github.com/vapor/vapor) 4.0 或以上版本是这个 package 的 dependency 。当在 package 中添加了 dependency 后，接下来你必须设置 targets。

### Targets

Targets 包含了所有的 modules、executables 以及 tests。

虽然可以添加任意多的 targets 来组织代码，但大部分 Vapor 应用有 3 个 target 就足够了。每个 target 声明了它依赖的 module 。为了在代码中可以 import 这些 modules ，你必须添加 module 名字。一个 target 可以依赖于工程中其它的 target 或者暴露出来的 modules。

!!! tip
    Executable targets (包含 `main.swift` 文件的 target) 不能被其它 modules 导入。这就是为什么 Vapor 会有 `App` 和 `Run` 两种 target。任何包含在 App 中的代码都可以在 `AppTests` 中被测试验证。

## Folder Structure

以下是典型的 SPM package 目录结构。

```
.
├── Sources
│   ├── App
│   │   └── (Source code)
│   └── Run
│       └── main.swift
├── Tests
│   └── AppTests
└── Package.swift
```

每个 `.target` 对应 `Sources` 中的一个文件夹。
每个 `.testTarget` 对应 `Tests` 中的一个文件夹。

## Package.resolved

第一次构建成功后，SPM 将会自动创建一个 `Package.resolved` 文件。`Package.resolved` 保存了当前项目所有用到的 `dependency` 版本。

更新依赖, 运行 `swift package update`.

## Xcode

如果使用 Xcode 11 或更高版本，则在修改 `Package.swift`文件时，将自动更改 dependencies、targets、products 等。

如果要更新到最新的依赖项。请使用 File &rarr; Swift Packages &rarr; 更新到最新的Swift软件包版本


您可能还想将 `.swiftpm` 文件添加到您的 `.gitignore` 文件中（Xcode 在此处存储 Xcode 项目配置）
