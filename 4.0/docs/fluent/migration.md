# 迁移

迁移就像是你的数据库的一个版本控制系统。每个迁移都定义了对数据库的改变，以及如何撤销它。通过迁移来修改你的数据库，你创建了一个一致的、可测试的、可共享的方式来逐步发展你的数据库。

```swift
// 一个迁移的例子。
struct MyMigration: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        // 对数据库做一个改变。
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        // 如果可能的话，撤消在`prepare`中所作的修改。
    }
}
```

如果你使用`async`/`await`，你应该实现`AsyncMigration`协议。

```swift
struct MyMigration: AsyncMigration {
    func prepare(on database: Database) async throws {
        // 对数据库做一个改变。
    }

    func revert(on database: Database) async throws {
        // 如果可能的话，撤消在`prepare`中所作的修改。
    }
}
```

`prepare`方法是你对提供的`Database`进行修改的地方。这可能是对数据库模式的改变，比如添加或删除一个表或集合、字段或约束。他们也可以修改数据库内容，比如创建新的模型实例，更新字段值，或者进行清理。

如果可能的话，`revert`方法是你撤销这些修改的地方。能够撤销迁移可以使原型设计和测试更加容易。如果部署到生产中的工作没有按计划进行，他们也会给你一个备份计划。

## 注册

使用`app.migrations`将迁移注册到你的应用程序中。

```swift
import Fluent
import Vapor

app.migrations.add(MyMigration())
```

你可以使用`to`参数将迁移添加到一个特定的数据库，否则将使用默认数据库。

```swift
app.migrations.add(MyMigration(), to: .myDatabase)
```

迁移应该按照依赖性的顺序排列。例如，如果`MigrationB`依赖于`MigrationA`，那么它应该被添加到`app.migrations`的第二部分。

## 迁移

为了迁移数据库，运行`migrate`命令。

```sh
vapor run migrate
```

你也可以通过运行[Xcode命令](../advanced/commands.md#xcode)。migrate命令会检查数据库，看自它上次运行以来是否有新的迁移被注册。如果有新的迁移，它将在运行前要求确认。

### 恢复

要撤销数据库中的迁移，可以在运行`migrate`时加上`--revert`标志。

```sh
vapor run migrate --revert
```

该命令将检查数据库，看最后运行的是哪一批迁移，并在恢复这些迁移之前要求进行确认。

### 自动迁移

如果你希望在运行其他命令之前自动运行迁移，你可以通过`--auto-migrate`标志。

```sh
vapor run serve --auto-migrate
```

你也可以通过编程来完成这个任务。

```swift
try app.autoMigrate().wait()

// 或者
try await app.autoMigrate()
```

这两个选项也都是用于还原的。`--auto-revert`和`app.autoRevert()`。

## 接下来的步骤

看看[schema builder](schema.md)和[query builder](query.md)指南，了解更多关于在迁移过程中应该放什么的信息。
