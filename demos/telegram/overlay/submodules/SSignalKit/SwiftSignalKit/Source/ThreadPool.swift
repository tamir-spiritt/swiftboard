import Foundation

public final class ThreadPoolTaskState {
    public let cancelled = Atomic<Bool>(value: false)
}

public final class ThreadPoolTask {
    private let state = ThreadPoolTaskState()
    private let action: (ThreadPoolTaskState) -> ()
    
    public init(_ action: @escaping(ThreadPoolTaskState) -> ()) {
        self.action = action
    }
    
    public func execute() {
        if !state.cancelled.with({ $0 })  {
            self.action(self.state)
        }
    }
    
    public func cancel() {
        let _ = self.state.cancelled.swap(true)
    }
}

public final class ThreadPoolQueue : Equatable {
    private weak var threadPool: ThreadPool?
    private var tasks: [ThreadPoolTask] = []
    
    public init(threadPool: ThreadPool) {
        self.threadPool = threadPool
    }
    
    public func addTask(_ task: ThreadPoolTask) {
        if let threadPool = self.threadPool {
            threadPool.workOnQueue(self, action: {
                self.tasks.append(task)
            })
        }
    }
    
    fileprivate func popFirstTask() -> ThreadPoolTask? {
        if self.tasks.count != 0 {
            let task = self.tasks[0];
            self.tasks.remove(at: 0)
            return task
        } else {
            return nil
        }
    }
    
    fileprivate func hasTasks() -> Bool {
        return self.tasks.count != 0
    }
}

public func ==(lhs: ThreadPoolQueue, rhs: ThreadPoolQueue) -> Bool {
    return lhs === rhs
}

// Swiftboard web port: browsers give WebAssembly one thread, so the pool runs its tasks on the
// shared event loop instead of OS threads. Public API is unchanged.
public final class ThreadPool {
    private var queues: [ThreadPoolQueue] = []
    private var scheduled = false

    public init(threadCount: Int, threadPriority: Double) {
        assert(threadCount > 0, "threadCount < 0")
    }

    public func addTask(_ task: ThreadPoolTask) {
        let tempQueue = self.nextQueue()
        tempQueue.addTask(task)
    }

    fileprivate func workOnQueue(_ queue: ThreadPoolQueue, action: () -> ()) {
        action()
        if !self.queues.contains(queue) {
            self.queues.append(queue)
        }
        if !self.scheduled {
            self.scheduled = true
            DispatchQueue.global().async { [weak self] in self?.drain() }
        }
    }

    private func drain() {
        self.scheduled = false
        while !self.queues.isEmpty {
            let queue = self.queues.removeFirst()
            while let task = queue.popFirstTask() {
                task.execute()
            }
        }
    }

    public func nextQueue() -> ThreadPoolQueue {
        return ThreadPoolQueue(threadPool: self)
    }

    public func isCurrentThreadInPool() -> Bool {
        return false
    }
}
