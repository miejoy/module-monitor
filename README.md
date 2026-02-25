# ModuleMonitor

ModuleMonitor 是一个轻量级的 Swift 模块监视器，用于实现观察者模式来记录和分发事件。该模块提供了线程安全的事件分发机制，支持多个观察者同时监听事件，并能在观察者释放时自动清理。

[![Swift](https://github.com/miejoy/module-monitor/actions/workflows/test.yml/badge.svg)](https://github.com/miejoy/module-monitor/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/miejoy/module-monitor/branch/main/graph/badge.svg)](https://codecov.io/gh/miejoy/module-monitor)
[![License](https://img.shields.io/badge/license-MIT-brightgreen.svg)](LICENSE)
[![Swift](https://img.shields.io/badge/swift-6.2-brightgreen.svg)](https://swift.org)

## 依赖

- iOS 13.0+ / macOS 10.15+ / tvOS 13.0+ / watchOS 6.0+
- Xcode 26.0+
- Swift 6.2+

## 简介

该模块包含几个核心概念需要提前了解:

- **MonitorEvent**: 监视器可接受的事件协议，所有自定义事件都需要遵循此协议并提供 `static func fatalError(_ message: String) -> Self` 方法
- **MonitorObserver**: 监视器观察者协议，所有观察者都需要遵循此协议
- **ModuleMonitor**: 模块监视器核心类，负责管理观察者和分发事件
- **AnyCancellable**: 用于取消观察的令牌，当令牌被释放或取消时，观察者会自动从监视器中移除
## 特性

- 线程安全：所有操作都在专用的 monitorQueue 中执行，确保线程安全
- 自动清理：观察者释放时会自动从监视器中移除
- 多观察者支持：支持多个观察者同时监听同一个监视器
- 致命错误处理：提供致命错误处理机制，在 DEBUG 模式下会触发 fatal error

## 安装

### [Swift Package Manager](https://github.com/apple/swift-package-manager)

在项目中的 Package.swift 文件添加如下依赖:

```swift
dependencies: [
    .package(url: "https://github.com/miejoy/module-monitor.git", from: "0.1.0"),
]
```

## 使用

### 基础使用

1、定义一个事件

```swift
import ModuleMonitor

enum AppEvent: MonitorEvent {
    case userLogin(String)
    case userLogout
    case fatalError(String)
}
```

2、定义一个观察者

```swift
import ModuleMonitor

class AppObserver: MonitorObserver, @unchecked Sendable {
    func handleEvent(_ event: AppEvent) {
        switch event {
        case .userLogin(let username):
            print("User logged in: \(username)")
        case .userLogout:
            print("User logged out")
        case .fatalError(let message):
            print("Fatal error: \(message)")
        }
    }
}
```

3、创建监视器并添加观察者

```swift
import ModuleMonitor

let monitor = ModuleMonitor<AppEvent> { event, observer in
    guard let appObserver = observer as? AppObserver else { return }
    appObserver.handleEvent(event)
}

let observer = AppObserver()
let cancellable = monitor.addObserver(observer)

monitor.record(event: .userLogin("John"))

cancellable.cancel()
```

### 多观察者场景

```swift
import ModuleMonitor

let monitor = ModuleMonitor<AppEvent> { event, observer in
    guard let appObserver = observer as? AppObserver else { return }
    appObserver.handleEvent(event)
}

let observer1 = AppObserver()
let observer2 = AppObserver()
let observer3 = AppObserver()

let cancellable1 = monitor.addObserver(observer1)
let cancellable2 = monitor.addObserver(observer2)
let cancellable3 = monitor.addObserver(observer3)

monitor.record(event: .userLogin("Alice"))

cancellable1.cancel()
cancellable2.cancel()
cancellable3.cancel()
```

### 致命错误处理

```swift
import ModuleMonitor

let monitor = ModuleMonitor<AppEvent> { event, observer in
    guard let appObserver = observer as? AppObserver else { return }
    appObserver.handleEvent(event)
}

let observer = AppObserver()
let cancellable = monitor.addObserver(observer)

monitor.fatalError("Critical error occurred")

cancellable.cancel()
```

### 在 SwiftUI 中使用

```swift
import ModuleMonitor
import SwiftUI

class ViewModel: ObservableObject, MonitorObserver {
    @Published var message: String = ""
    
    func handleEvent(_ event: AppEvent) {
        switch event {
        case .userLogin(let username):
            message = "Welcome, \(username)!"
        default:
            break
        }
    }
}

struct ContentView: View {
    @StateObject private var viewModel = ViewModel()
    private let monitor = ModuleMonitor<AppEvent> { event, observer in
        guard let vm = observer as? ViewModel else { return }
        vm.handleEvent(event)
    }
    
    var body: some View {
        VStack {
            Text(viewModel.message)
            Button("Login") {
                monitor.record(event: .userLogin("Bob"))
            }
        }
        .onAppear {
            _ = monitor.addObserver(viewModel)
        }
    }
}
```

## API 文档

### ModuleMonitor

#### 初始化

```swift
public init(notifyObserver: @escaping (Event, MonitorObserver) -> Void)
```

初始化监视器，传入通知观察者的回调函数。

#### 添加观察者

```swift
@discardableResult
public func addObserver(_ observer: MonitorObserver) -> AnyCancellable
```

添加一个观察者，返回一个可取消的令牌。

#### 记录事件

```swift
public func record(event: Event)
```

记录一个事件，并将该事件分发给所有观察者。

#### 致命错误

```swift
public func fatalError(_ message: String)
```

抛出致命错误，在 DEBUG 模式下会触发 Swift.fatalError，否则只记录事件。监视器会自动调用 `Event.fatalError(message)` 来创建事件。

## 作者

Raymond.huang: raymond0huang@gmail.com

## License

ModuleMonitor is available under MIT license. See LICENSE file for more info.
