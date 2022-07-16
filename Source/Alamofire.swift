import Dispatch
import Foundation
#if canImport(FoundationNetworking)
@_exported import FoundationNetworking
#endif

/// Reference to `Session.default` for quick bootstrapping and examples.
public let AF = Session.default

/// Current Alamofire version. Necessary since SPM doesn't use dynamic libraries. Plus this will be more accurate.
// 这其实挺重要的. 可以的是, 大部分库的作者, 都不知道应该在自己库中将 Version 暴露出来. 
let version = "5.6.1"
