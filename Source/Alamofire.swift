import Dispatch
import Foundation
#if canImport(FoundationNetworking)
@_exported import FoundationNetworking
#endif

// Enforce minimum Swift version for all platforms and build systems.
// 直接就编译器报错了. 这样能够强制进行提示.
#if swift(<5.9.0)
#error("Alamofire doesn't support Swift versions below 5.9.")
#endif

/// Reference to `Session.default` for quick bootstrapping and examples.
// 这里专门定义一个可以快捷使用的全局变量, 避免定义 Session 了 
public let AF = Session.default

/// Namespace for informational Alamofire values.
public enum AFInfo {
    /// Current Alamofire version.
    public static let version = "5.10.2"
}
