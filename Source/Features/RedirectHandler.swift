import Foundation

/// A type that handles how an HTTP redirect response from a remote server should be redirected to the new request.
public protocol RedirectHandler: Sendable {
    /// Determines how the HTTP redirect response should be redirected to the new request.
    ///
    /// The `completion` closure should be passed one of three possible options:
    ///
    ///   1. The new request specified by the redirect (this is the most common use case).
    ///   2. A modified version of the new request (you may want to route it somewhere else).
    ///   3. A `nil` value to deny the redirect request and return the body of the redirect response.
    ///
    /// - Parameters:
    ///   - task:       The `URLSessionTask` whose request resulted in a redirect.
    ///   - request:    The `URLRequest` to the new location specified by the redirect response.
    ///   - response:   The `HTTPURLResponse` containing the server's response to the original request.
    ///   - completion: The closure to execute containing the new `URLRequest`, a modified `URLRequest`, or `nil`.
    
    /// 一个处理远程服务器的 HTTP 重定向响应应如何重定向到新请求的类型。
    /// 确定 HTTP 重定向响应应如何重定向到新请求。
    ///
    /// completion 闭包应传递三种可能的选项之一：
    ///
    /// 1. 由重定向指定的新请求（这是最常见的用例）。
    /// 2. 新请求的修改版本（您可能希望将其路由到其他位置）。
    /// 3. 一个 nil 值，拒绝重定向请求并返回重定向响应的主体。
    ///
    /// - Parameters:
    /// - task: 导致重定向的 URLSessionTask。
    /// - request: 由重定向响应指定的新位置的 URLRequest。
    /// - response: 包含服务器对原始请求的响应的 HTTPURLResponse。
    /// - completion: 包含新的 URLRequest、修改后的 URLRequest 或 nil 的闭包
    func task(_ task: URLSessionTask,
              willBeRedirectedTo request: URLRequest,
              for response: HTTPURLResponse,
              completion: @escaping (URLRequest?) -> Void)
}

// MARK: -

/// `Redirector` is a convenience `RedirectHandler` making it easy to follow, not follow, or modify a redirect.
public struct Redirector {
    /// Defines the behavior of the `Redirector` type.
    public enum Behavior: Sendable {
        /// Follow the redirect as defined in the response.
        case follow
        /// Do not follow the redirect defined in the response.
        case doNotFollow
        /// Modify the redirect request defined in the response.
        case modify(@Sendable (_ task: URLSessionTask, _ request: URLRequest, _ response: HTTPURLResponse) -> URLRequest?)
    }

    /// Returns a `Redirector` with a `.follow` `Behavior`.
    public static let follow = Redirector(behavior: .follow)
    /// Returns a `Redirector` with a `.doNotFollow` `Behavior`.
    public static let doNotFollow = Redirector(behavior: .doNotFollow)

    /// The `Behavior` of the `Redirector`.
    public let behavior: Behavior

    /// Creates a `Redirector` instance from the `Behavior`.
    ///
    /// - Parameter behavior: The `Behavior`.
    public init(behavior: Behavior) {
        self.behavior = behavior
    }
}

// MARK: -

extension Redirector: RedirectHandler {
    public func task(_ task: URLSessionTask,
                     willBeRedirectedTo request: URLRequest,
                     for response: HTTPURLResponse,
                     completion: @escaping (URLRequest?) -> Void) {
        switch behavior {
        case .follow:
            completion(request)
        case .doNotFollow:
            completion(nil)
        case let .modify(closure):
            let request = closure(task, request, response)
            completion(request)
        }
    }
}

extension RedirectHandler where Self == Redirector {
    /// Provides a `Redirector` which follows redirects. Equivalent to `Redirector.follow`.
    public static var follow: Redirector { .follow }

    /// Provides a `Redirector` which does not follow redirects. Equivalent to `Redirector.doNotFollow`.
    public static var doNotFollow: Redirector { .doNotFollow }

    /// Creates a `Redirector` which modifies the redirected `URLRequest` using the provided closure.
    ///
    /// - Parameter closure: Closure used to modify the redirect.
    /// - Returns:           The `Redirector`.
    public static func modify(using closure: @escaping @Sendable (URLSessionTask, URLRequest, HTTPURLResponse) -> URLRequest?) -> Redirector {
        Redirector(behavior: .modify(closure))
    }
}
