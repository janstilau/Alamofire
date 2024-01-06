import Foundation

extension URLSessionConfiguration: AlamofireExtended {}

extension AlamofireExtension where ExtendedType: URLSessionConfiguration {
    /// Alamofire's default configuration. Same as `URLSessionConfiguration.default` but adds Alamofire default
    /// `Accept-Language`, `Accept-Encoding`, and `User-Agent` headers.
    public static var `default`: URLSessionConfiguration {
        // 在这里, 给 Session 添加了一些默认的请求头的信息. 
        let configuration = URLSessionConfiguration.default
        configuration.headers = .default
        return configuration
    }

    /// `.ephemeral` configuration with Alamofire's default `Accept-Language`, `Accept-Encoding`, and `User-Agent`
    /// headers.
    public static var ephemeral: URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.headers = .default

        return configuration
    }
}
