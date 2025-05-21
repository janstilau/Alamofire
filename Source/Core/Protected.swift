import Foundation

private protocol Lock: Sendable {
    func lock()
    func unlock()
}

// lock, unlock 是一般缩都有的.
// 这里主要是通过 extension, 给这些锁增加一些公用的方法, 就像一个抽象类一样, 增加公用的一些方法.
// 一般来说, 就是这种工具性的方法, 就是定义一个泛型的返回值的函数, 一定 Void 返回值的函数.
// 但是从编译角度来说, 只写一个 -> T 的也是没有问题的.
extension Lock {
    /// Executes a closure returning a value while acquiring the lock.
    ///
    /// - Parameter closure: The closure to run.
    ///
    /// - Returns:           The value the closure generated.
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

#if canImport(Darwin)
// Number of Apple engineers who insisted on inspecting this: 5
/// An `os_unfair_lock` wrapper.
//
final class UnfairLock: Lock, @unchecked Sendable {
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

// 给其他库的类增加自己的 protocol 实现, 或者给自己的类增加对方的 protocol 实现, 都是可行的.
#elseif canImport(Foundation)
extension NSLock: Lock {}
#else
#error("This platform needs a Lock-conforming type without Foundation.")
#endif

/// A thread-safe wrapper around a value.
// 允许你在编译时未声明的属性名，通过下标方法动态处理访问。
// 编译器遇到 p.name 时，发现 Person 没有 name 属性，但因为加了 @dynamicMemberLookup，它会自动把 p.name 转换为 p[dynamicMember: "name"]，调用你实现的下标方法。
@dynamicMemberLookup
final class Protected<Value> {
#if canImport(Darwin)
    private let lock = UnfairLock()
#elseif canImport(Foundation)
    private let lock = NSLock()
#else
#error("This platform needs a Lock-conforming type without Foundation.")
#endif
    
#if compiler(>=6)
    private nonisolated(unsafe) var value: Value
#else
    private var value: Value
#endif
    
    init(_ value: Value) {
        self.value = value
    }
    
    /// Synchronously read or transform the contained value.
    ///
    /// - Parameter closure: The closure to execute.
    ///
    /// - Returns:           The return value of the closure passed.
    func read<U>(_ closure: (Value) throws -> U) rethrows -> U {
        try lock.around { try closure(self.value) }
    }
    
    /// Synchronously modify the protected value.
    ///
    /// - Parameter closure: The closure to execute.
    ///
    /// - Returns:           The modified value.
    // 当需要修改的时候, 就传入 inout 修饰的属性.
    @discardableResult
    func write<U>(_ closure: (inout Value) throws -> U) rethrows -> U {
        try lock.around { try closure(&self.value) }
    }
    
    /// Synchronously update the protected value.
    ///
    /// - Parameter value: The `Value`.
    func write(_ value: Value) {
        write { $0 = value }
    }
    
    /*
     KeyPath 是 Swift 语言的一种类型安全的“属性路径”引用方式。
     它允许你用一种“对象化”的方式，间接访问某个类型的属性，而不是直接用点语法访问。

     你可以把 KeyPath 理解为“属性的指针”或“属性的路径”。
     它不是属性的值，而是“如何找到这个属性”的描述。
     
     只能访问类型上已经定义的属性。
     你不能用 KeyPath 访问不存在的属性，也不能用 KeyPath 动态“创造”属性。
     KeyPath 只能访问 public/internal 属性，private 属性在类型外不可用
     */
    
    // 使用 KeyPath 的这种方式, 只能用来访问已有的属性.
    // 支持 读写
    // 这里 Keypath 在定义的时候, 要把 Contianer 的类型传递过去. 这样在实际编码的时候, 才不会发生错误. 
    subscript<Property>(dynamicMember keyPath: WritableKeyPath<Value, Property>) -> Property {
        get { lock.around { value[keyPath: keyPath] } }
        set { lock.around { value[keyPath: keyPath] = newValue } }
    }
    
    // 只支持读
    subscript<Property>(dynamicMember keyPath: KeyPath<Value, Property>) -> Property {
        lock.around { value[keyPath: keyPath] }
    }
}

#if compiler(>=6)
extension Protected: Sendable {}
#else
extension Protected: @unchecked Sendable {}
#endif

extension Protected where Value == Request.MutableState {
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

// lock 这个是线程同步的写法. 所以虽然有闭包, 但这是一个渐进式的过程.
extension Protected: Equatable where Value: Equatable {
    static func ==(lhs: Protected<Value>, rhs: Protected<Value>) -> Bool {
        lhs.read { left in rhs.read { right in left == right }}
    }
}

extension Protected: Hashable where Value: Hashable {
    func hash(into hasher: inout Hasher) {
        read { hasher.combine($0) }
    }
}
