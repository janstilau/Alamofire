import Dispatch
import Foundation
#if canImport(FoundationNetworking)
@_exported import FoundationNetworking
#endif

// Enforce minimum Swift version for all platforms and build systems.
#if swift(<5.5)
#error("Alamofire doesn't support Swift versions below 5.5.")
#endif

/// Reference to `Session.default` for quick bootstrapping and examples.
public let AF = Session.default

/// Current Alamofire version. Necessary since SPM doesn't use dynamic libraries. Plus this will be more accurate.
// 专门的给自己的类库, 用给一个显式的方式, 设置版本号是非常好的一个习惯. 
let version = "5.8.0"
