import Foundation

extension URLRequest {
    /// Returns the `httpMethod` as Alamofire's `HTTPMethod` type.
    public var method: HTTPMethod? {
        // 原来可以使用, HTTPMethod.init 这种方式来传递闭包. 
        get { httpMethod.map(HTTPMethod.init) }
        set { httpMethod = newValue?.rawValue }
    }
    
    // 这里的简单测试, 就是 Get 不能有 Body. 
    public func validate() throws {
        if method == .get, let bodyData = httpBody {
            throw AFError.urlRequestValidationFailed(reason: .bodyDataInGETRequest(bodyData))
        }
    }
}
