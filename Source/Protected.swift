import Foundation

private protocol Lock {
    func lock()
    func unlock()
}

// 应该大量的使用 defer 这种设置.
// 应该大量的使用 throw 是和 rethrows.
extension Lock {
    /// Executes a closure returning a value while acquiring the lock.
    ///
    /// - Parameter closure: The closure to run.
    ///
    /// - Returns:           The value the closure generated.
    // 通过闭包的返回值, 来确定返回值的类型, 这是一个非常常见的思路.
    func around<T>(_ closure: () throws -> T) rethrows -> T {
        lock(); defer { unlock() }
        return try closure()
    }

    /// Execute a closure while acquiring the lock.
    ///
    /// - Parameter closure: The closure to run.
    func around(_ closure: () throws -> Void) rethrows {
        lock(); defer { unlock() }
        try closure()
    }
}

#if os(Linux) || os(Windows) || os(Android)

extension NSLock: Lock {}

#endif

#if canImport(Darwin)
/// An `os_unfair_lock` wrapper.
final class UnfairLock: Lock {
    private let unfairLock: os_unfair_lock_t

    init() {
        unfairLock = .allocate(capacity: 1)
        unfairLock.initialize(to: os_unfair_lock())
    }

    deinit {
        unfairLock.deinitialize(count: 1)
        unfairLock.deallocate()
    }

    fileprivate func lock() {
        os_unfair_lock_lock(unfairLock)
    }

    fileprivate func unlock() {
        os_unfair_lock_unlock(unfairLock)
    }
}
#endif

/// A thread-safe wrapper around a value.
@propertyWrapper
@dynamicMemberLookup
final class Protected<T> {
    #if canImport(Darwin)
    private let lock = UnfairLock()
    #elseif os(Linux) || os(Windows) || os(Android)
    private let lock = NSLock()
    #endif
    private var value: T

    init(_ value: T) {
        self.value = value
    }

    /// The contained value. Unsafe for anything more than direct read or write.
    var wrappedValue: T {
        get { lock.around { value } }
        set { lock.around { value = newValue } }
    }

    var projectedValue: Protected<T> { self }

    init(wrappedValue: T) {
        value = wrappedValue
    }

    /// Synchronously read or transform the contained value.
    ///
    /// - Parameter closure: The closure to execute.
    ///
    /// - Returns:           The return value of the closure passed.
    func read<U>(_ closure: (T) throws -> U) rethrows -> U {
        try lock.around { try closure(self.value) }
    }

    /// Synchronously modify the protected value.
    ///
    /// - Parameter closure: The closure to execute.
    ///
    /// - Returns:           The modified value.
    @discardableResult
    func write<U>(_ closure: (inout T) throws -> U) rethrows -> U {
        // 这里传递引用过去, 所以可以进行值的覆盖. 
        try lock.around { try closure(&self.value) }
    }

    // 就算是使用 $mutableState.state 的方式, 获取 state 的这个值, 还是会在锁的环境下. 
    subscript<Property>(dynamicMember keyPath: WritableKeyPath<T, Property>) -> Property {
        get { lock.around { value[keyPath: keyPath] } }
        set { lock.around { value[keyPath: keyPath] = newValue } }
    }

    subscript<Property>(dynamicMember keyPath: KeyPath<T, Property>) -> Property {
        lock.around { value[keyPath: keyPath] }
    }
}

extension Protected where T == Request.MutableState {
    /// Attempts to transition to the passed `State`.
    ///
    /// - Parameter state: The `State` to attempt transition to.
    ///
    /// - Returns:         Whether the transition occurred.
    func attemptToTransitionTo(_ state: Request.State) -> Bool {
        lock.around {
            guard value.state.canTransitionTo(state) else { return false }

            value.state = state

            return true
        }
    }

    /// Perform a closure while locked with the provided `Request.State`.
    ///
    /// - Parameter perform: The closure to perform while locked.
    func withState(perform: (Request.State) -> Void) {
        lock.around { perform(value.state) }
    }
}
