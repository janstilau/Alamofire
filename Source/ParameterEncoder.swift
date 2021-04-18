import Foundation


// 外界只会使用该接口.
// 这个接口的作用, 是将 参数, 添加到 request 里面去
public protocol ParameterEncoder {
    /// Encode the provided `Encodable` parameters into `request`.
    ///
    /// - Parameters:
    ///   - parameters: The `Encodable` parameter value.
    ///   - request:    The `URLRequest` into which to encode the parameters.
    ///
    /// - Returns:      A `URLRequest` with the result of the encoding.
    /// - Throws:       An `Error` when encoding fails. For Alamofire provided encoders, this will be an instance of
    ///                 `AFError.parameterEncoderFailed` with an associated `ParameterEncoderFailureReason`.
    func encode<Parameters: Encodable>(_ parameters: Parameters?, into request: URLRequest) throws -> URLRequest
}

// AFN 里面的 JSONSerializor, 也是拿到 dict 之后, 使用系统的 JSON 序列化器完成的序列化.
// 这里, 使用的是 JSONEncoder 进行相关的序列化操作.
open class JSONParameterEncoder: ParameterEncoder {
    // 几个静态方法, 返回配置好的 JSONParameterEncoder 对象.
    // 都是返回新的值.
    public static var `default`: JSONParameterEncoder { JSONParameterEncoder() }
    public static var prettyPrinted: JSONParameterEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return JSONParameterEncoder(encoder: encoder)
    }
    @available(iOSApplicationExtension 11.0, *)
    public static var sortedKeys: JSONParameterEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return JSONParameterEncoder(encoder: encoder)
    }
    
    // JSON 的序列化器, 就不存在 param 的输出位置的问题了.
    public let encoder: JSONEncoder
    public init(encoder: JSONEncoder = JSONEncoder()) {
        self.encoder = encoder
    }
    
    open func encode<Parameters: Encodable>(_ parameters: Parameters?,
                                            into request: URLRequest) throws -> URLRequest {
        guard let parameters = parameters else { return request }
        var request = request
        do {
            let data = try encoder.encode(parameters)
            request.httpBody = data
            if request.headers["Content-Type"] == nil {
                request.headers.update(.contentType("application/json"))
            }
        } catch {
            throw AFError.parameterEncodingFailed(reason: .jsonEncodingFailed(error: error))
        }
        return request
    }
}

/// A `ParameterEncoder` that encodes types as URL-encoded query strings to be set on the URL or as body data, depending
/// on the `Destination` set.
///
/// If no `Content-Type` header is already set on the provided `URLRequest`s, it will be set to
/// `application/x-www-form-urlencoded; charset=utf-8`.
///
/// Encoding behavior can be customized by passing an instance of `URLEncodedFormEncoder` to the initializer.
open class URLEncodedFormParameterEncoder: ParameterEncoder {
    
    // 专门一个类, 来表示参数的位置.
    public enum Destination {
        // 根据方法来, GET, DELETE, HEAD 会在 URL 里面, 其他的会在 BODY 里面.
        case methodDependent
        // 显式地声明, params 会在 URL 里面
        case queryString
        // 显式地声明, params 会在 body 里面.
        case httpBody
        
        /// Determines whether the URL-encoded string should be applied to the `URLRequest`'s `url`.
        ///
        /// - Parameter method: The `HTTPMethod`.
        ///
        /// - Returns:          Whether the URL-encoded string should be applied to a `URL`.
        func encodesParametersInURL(for method: HTTPMethod) -> Bool {
            switch self {
            case .methodDependent: return [.get, .head, .delete].contains(method)
            case .queryString: return true
            case .httpBody: return false
            }
        }
    }
    
    /// Returns an encoder with default parameters.
    public static var `default`: URLEncodedFormParameterEncoder { URLEncodedFormParameterEncoder()
    }
    
    /// The `URLEncodedFormEncoder` to use.
    public let encoder: URLEncodedFormEncoder
    
    // 如何将参数, 序列化到 Reuqest
    public let destination: Destination
    
    public init(encoder: URLEncodedFormEncoder = URLEncodedFormEncoder(), destination: Destination = .methodDependent) {
        self.encoder = encoder
        self.destination = destination
    }
    
    open func encode<Parameters: Encodable>(_ parameters: Parameters?,
                                            into request: URLRequest) throws -> URLRequest {
        // 这里, Encodable 更加的抽象, 可以直接传递 model 过来, 也可以传递 NSDict 过来.
        // 如果有必要, 可以专门为接口, 设计 Model. 在那种复杂接口, 应该可以. 将参数的组装过程, 使用一个 Model 内进行内置.
        guard let parameters = parameters else { return request }
        
        // let => var 的改变.
        var request = request
        
        guard let url = request.url else {
            throw AFError.parameterEncoderFailed(reason: .missingRequiredComponent(.url))
        }
        
        guard let method = request.method else {
            let rawValue = request.method?.rawValue ?? "nil"
            throw AFError.parameterEncoderFailed(reason: .missingRequiredComponent(.httpMethod(rawValue: rawValue)))
        }
        
        if destination.encodesParametersInURL(for: method),
           var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            let query: String = try
                // encoder.encode 到底是 String, 还是 Data 返回, 是看返回值的.
                // 这里, Result 里面是 String, 所以调用的就是 String 的方法.
                Result<String, Error> { try encoder.encode(parameters) }
                .mapError { AFError.parameterEncoderFailed(reason: .encoderFailed(error: $0)) }
                .get()
            let newQueryString = [components.percentEncodedQuery, query].compactMap { $0 }.joinedWithAmpersands()
            components.percentEncodedQuery = newQueryString.isEmpty ? nil : newQueryString
            
            guard let newURL = components.url else {
                throw AFError.parameterEncoderFailed(reason: .missingRequiredComponent(.url))
            }
            request.url = newURL
        } else {
            if request.headers["Content-Type"] == nil {
                request.headers.update(.contentType("application/x-www-form-urlencoded; charset=utf-8"))
            }
            request.httpBody =
                // try 是为了后面的 get
                // 首先是 encoder.encode(parameters), 这个调用来组成 Result
                // 然后, Result.mapError 会将 Result 失败的情况进行修改, 变为 AF 的 Error
                // Get 会返回里面的 Data. 如果有错就会 throw.
                try Result<Data, Error> { try encoder.encode(parameters) }
                .mapError { AFError.parameterEncoderFailed(reason: .encoderFailed(error: $0)) }
                .get()
        }
        
        return request
    }
}
