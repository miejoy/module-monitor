//
//  ModuleMonitor.swift
//  module-monitor
//
//  Created by 黄磊 on 2026/2/25.
//

import Combine
import Dispatch

/// 监视器可接受事件
public protocol MonitorEvent: Sendable {
    static func fatalError(_ message: String) -> Self
}

/// 监视器观察者
public protocol MonitorObserver: AnyObject, Sendable {
}

/// 模块监视器
open class ModuleMonitor<Event: MonitorEvent> {
    struct Observer {
        let observerId: Int
        weak var observer: MonitorObserver?
    }
    
    /// 所有观察者
    var arrObservers: [Observer] = []
    /// 用于生成观察者ID
    var generateObserverId: Int = 0
    /// 通知观察者
    let notifyObserver: (Event, MonitorObserver) -> Void

    
    /// 初始化监听器
    /// - Parameter notifyObserver: 通知观察者回调，会被包裹在 MonitorQueue 线程
    public required init(notifyObserver: @escaping (Event, MonitorObserver) -> Void) {
        self.notifyObserver = notifyObserver
    }
    
    /// 添加观察者
    open func addObserver(_ observer: MonitorObserver) -> AnyCancellable {
        DispatchQueue.syncOnMonitorQueue {
            generateObserverId += 1
            let observerId = generateObserverId
            arrObservers.append(.init(observerId: generateObserverId, observer: observer))
            return AnyCancellable { [weak self] in
                if let index = self?.arrObservers.firstIndex(where: { $0.observerId == observerId}) {
                    self?.arrObservers.remove(at: index)
                }
            }
        }
    }
    
    /// 记录对应事件，这里只负责将所有事件传递给观察者
    public func record(event: Event) {
        DispatchQueue.syncOnMonitorQueue {
            guard !arrObservers.isEmpty else { return }
            arrObservers.forEach {
                guard let observer = $0.observer else { return }
                self.notifyObserver(event, observer)
            }
        }
    }
    
    /// 抛出致命异常
    public func fatalError(_ message: String) {
        DispatchQueue.syncOnMonitorQueue {
            guard !arrObservers.isEmpty else {
                #if DEBUG
                Swift.fatalError(message)
                #else
                return
                #endif
            }
            record(event: .fatalError(message))
        }
    }
}


// MARK: - MonitorQueue

extension DispatchQueue {
    static let monitorDispatchSpecificKey: DispatchSpecificKey<String> = .init()
    static let monitorQueue: DispatchQueue = {
        let queue = DispatchQueue(label: "module-monitor.monitor_queue")
        queue.setSpecific(key: monitorDispatchSpecificKey, value: queue.label)
        return queue
    }()
    
    /// 在 monitor 队列中执行
    public static func syncOnMonitorQueue<T>(execute work: () throws -> T) rethrows -> T {
        if DispatchQueue.getSpecific(key: Self.monitorDispatchSpecificKey) == Self.monitorQueue.label {
            return try work()
        }
        return try Self.monitorQueue.sync(execute: work)
    }
}
