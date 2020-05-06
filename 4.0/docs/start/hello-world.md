# 你好，世界

本文将指引你逐步创建、编译并运行 Vapor 的项目。

如果尚未安装 Swift 和 Vapor Toolbox，请查看安装部分。

- [安装 &rarr; macOS](../install/macos.md)
- [安装 &rarr; Ubuntu](../install/ubuntu.md)

## 创建

首先，在电脑上创建 Vapor 项目。

打开终端并使用以下 Toolbox 的命令行，这将会在当前目录创建一个包含 Vapor 项目的文件夹。

```sh
vapor-beta new hello -n
```

!!! tip
	使用 `-n` 参数会按照默认设置，为您提供一个简单的模板。

命令完成后，进入新创建的 Vapor 项目文件夹，并在 Xcode 中打开项目。

```sh
cd hello
open Package.swift
```

## 编译和运行

你现在可以打开 Xcode，单击 Run 按钮以构建并运行你的项目。

此时应该可以看到在屏幕底部输出的启动信息。

```sh
[ INFO ] Server starting on http://127.0.0.1:8080
```

## 本地访问

打开你的 Web 浏览器，然后访问 <a href="http://localhost:8080/hello" target="_blank">localhost:8080/hello</a>

你应该能够看到以下页面内容：

```html
Hello, world!
```

那么恭喜你！成功地创建和运行了你的第一个 Vapor 应用程序！ 🎉
