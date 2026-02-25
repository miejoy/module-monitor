//
//  ModuleMonitorTests.swift
//  module-monitor
//
//  Created by 黄磊 on 2026/2/25.
//

import Testing
import Combine
import Foundation
@testable import ModuleMonitor

@Suite
struct ModuleMonitorTests {
    
    @Test
    func testMonitorRecord() {
        let monitor = ModuleMonitor<TestEvent> { event, observer in
            guard let testObserver = observer as? TestObserver else { return }
            testObserver.receive(event)
        }
        
        let observer = TestObserver()
        let cancellable = monitor.addObserver(observer)
        
        monitor.record(event: .record("test message"))
        
        #expect(observer.receivedEvents.count == 1)
        if case .record(let message) = observer.receivedEvents[0] {
            #expect(message == "test message")
        } else {
            Issue.record("Expected .record event")
        }
        
        cancellable.cancel()
    }
    
    @Test
    func testMonitorFatalError() {
        let monitor = ModuleMonitor<TestEvent> { event, observer in
            guard let testObserver = observer as? TestObserver else { return }
            testObserver.receive(event)
        }
        
        let observer = TestObserver()
        let cancellable = monitor.addObserver(observer)
        
        monitor.fatalError("fatal error message")
        
        #expect(observer.receivedEvents.count == 1)
        if case .fatalError(let message) = observer.receivedEvents[0] {
            #expect(message == "fatal error message")
        } else {
            Issue.record("Expected .fatalError event")
        }
        
        cancellable.cancel()
    }
    
    @Test
    func testAddObserver() {
        let monitor = ModuleMonitor<TestEvent> { _, _ in }
        
        let observer1 = TestObserver()
        let cancellable1 = monitor.addObserver(observer1)
        
        #expect(monitor.arrObservers.count == 1)
        #expect(monitor.arrObservers[0].observerId == 1)
        
        let observer2 = TestObserver()
        let cancellable2 = monitor.addObserver(observer2)
        
        #expect(monitor.arrObservers.count == 2)
        #expect(monitor.arrObservers[1].observerId == 2)
        
        cancellable1.cancel()
        
        #expect(monitor.arrObservers.count == 1)
        #expect(monitor.arrObservers[0].observerId == 2)
        
        cancellable2.cancel()
    }
    
    @Test
    func testRemoveObserver() {
        let monitor = ModuleMonitor<TestEvent> { _, _ in }
        
        let observer = TestObserver()
        let cancellable = monitor.addObserver(observer)
        
        #expect(monitor.arrObservers.count == 1)
        
        cancellable.cancel()
        
        #expect(monitor.arrObservers.count == 0)
    }
    
    @Test
    func testMultipleObserversReceiveEvents() {
        let monitor = ModuleMonitor<TestEvent> { event, observer in
            guard let testObserver = observer as? TestObserver else { return }
            testObserver.receive(event)
        }
        
        let observer1 = TestObserver()
        let observer2 = TestObserver()
        let observer3 = TestObserver()
        
        let cancellable1 = monitor.addObserver(observer1)
        let cancellable2 = monitor.addObserver(observer2)
        let cancellable3 = monitor.addObserver(observer3)
        
        monitor.record(event: .record("broadcast message"))
        
        #expect(observer1.receivedEvents.count == 1)
        #expect(observer2.receivedEvents.count == 1)
        #expect(observer3.receivedEvents.count == 1)
        
        if case .record(let message) = observer1.receivedEvents[0] {
            #expect(message == "broadcast message")
        }
        
        if case .record(let message) = observer2.receivedEvents[0] {
            #expect(message == "broadcast message")
        }
        
        if case .record(let message) = observer3.receivedEvents[0] {
            #expect(message == "broadcast message")
        }
        
        cancellable1.cancel()
        cancellable2.cancel()
        cancellable3.cancel()
    }
    
    @Test
    func testObserverDeallocated() {
        let monitor = ModuleMonitor<TestEvent> { _, _ in }
        
        var cancellable: AnyCancellable?
        do {
            let observer = TestObserver()
            cancellable = monitor.addObserver(observer)
            #expect(monitor.arrObservers.count == 1)
        }
        
        #expect(monitor.arrObservers.count == 1)
        #expect(monitor.arrObservers[0].observer == nil)
        
        cancellable?.cancel()
    }
    
    @Test
    func testMultipleEvents() {
        let monitor = ModuleMonitor<TestEvent> { event, observer in
            guard let testObserver = observer as? TestObserver else { return }
            testObserver.receive(event)
        }
        
        let observer = TestObserver()
        let cancellable = monitor.addObserver(observer)
        
        monitor.record(event: .record("event 1"))
        monitor.record(event: .record("event 2"))
        monitor.record(event: .record("event 3"))
        
        #expect(observer.receivedEvents.count == 3)
        
        if case .record(let message) = observer.receivedEvents[0] {
            #expect(message == "event 1")
        }
        
        if case .record(let message) = observer.receivedEvents[1] {
            #expect(message == "event 2")
        }
        
        if case .record(let message) = observer.receivedEvents[2] {
            #expect(message == "event 3")
        }
        
        cancellable.cancel()
    }
    
    @Test
    func testEventWithoutObservers() {
        let monitor = ModuleMonitor<TestEvent> { event, observer in
            guard let testObserver = observer as? TestObserver else { return }
            testObserver.receive(event)
        }
        
        monitor.record(event: .record("no observers"))
        
        #expect(monitor.arrObservers.count == 0)
    }
    
    @Test
    func testObserverIdIncrement() {
        let monitor = ModuleMonitor<TestEvent> { _, _ in }
        
        let observer1 = TestObserver()
        let observer2 = TestObserver()
        let observer3 = TestObserver()
        
        let cancellable1 = monitor.addObserver(observer1)
        let cancellable2 = monitor.addObserver(observer2)
        let cancellable3 = monitor.addObserver(observer3)
        
        #expect(monitor.arrObservers[0].observerId == 1)
        #expect(monitor.arrObservers[1].observerId == 2)
        #expect(monitor.arrObservers[2].observerId == 3)
        
        cancellable1.cancel()
        cancellable2.cancel()
        cancellable3.cancel()
    }
}


// MARK: - Test Event and Observer

enum TestEvent: MonitorEvent {
    case record(String)
    case fatalError(String)
}

class TestObserver: MonitorObserver, @unchecked Sendable {
    var receivedEvents: [TestEvent] = []
    let lock = NSLock()
    
    func receive(_ event: TestEvent) {
        lock.lock()
        defer { lock.unlock() }
        receivedEvents.append(event)
    }
}
