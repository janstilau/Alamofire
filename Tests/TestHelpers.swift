import Alamofire
import Foundation

extension String {
    static let invalidURL = "invalid"
    static let nonexistentDomain = "https://nonexistent-domain.org"
}

extension URL {
    static let nonexistentDomain = URL(string: .nonexistentDomain)!
}

struct Endpoint {
    // 所有的一切,  都使用 Enum 来完成了封装.
    // 使用类型, 来代替基本的数据类型.
    enum Scheme: String {
        case http, https

        var port: Int {
            switch self {
            case .http: return 80
            case .https: return 443
            }
        }
    }

    enum Host: String {
        case localhost = "10.234.52.38"
        case httpBin = "httpbin.org"

        func port(for scheme: Scheme) -> Int {
            switch self {
            case .localhost: return 3000
            case .httpBin: return scheme.port
            }
        }
    }

    enum Path {
        case basicAuth(username: String, password: String)
        case bytes(count: Int)
        case cache
        case chunked(count: Int)
        case compression(Compression)
        case delay(interval: Int) // response 会晚点返回, 这是服务器那边的设置. 
        case digestAuth(qop: String = "auth", username: String, password: String)
        case download(count: Int)
        case hiddenBasicAuth(username: String, password: String)
        case image(Image)
        case ip
        case method(HTTPMethod)
        case payloads(count: Int)
        case redirect(count: Int)
        case redirectTo
        case responseHeaders
        case status(Int)
        case stream(count: Int)
        case upload
        case xml

        var string: String {
            switch self {
            case let .basicAuth(username: username, password: password):
                return "/basic-auth/\(username)/\(password)"
            case let .bytes(count):
                return "/bytes/\(count)"
            case .cache:
                return "/cache"
            case let .chunked(count):
                return "/chunked/\(count)"
            case let .compression(compression):
                return "/\(compression.rawValue)"
            case let .delay(interval):
                return "/delay/\(interval)"
            case let .digestAuth(qop, username, password):
                return "/digest-auth/\(qop)/\(username)/\(password)"
            case let .download(count):
                return "/download/\(count)"
            case let .hiddenBasicAuth(username, password):
                return "/hidden-basic-auth/\(username)/\(password)"
            case let .image(type):
                return "/image/\(type.rawValue)"
            case .ip:
                return "/ip"
            case let .method(method):
                return "/\(method.rawValue.lowercased())"
            case let .payloads(count):
                return "/payloads/\(count)"
            case let .redirect(count):
                return "/redirect/\(count)"
            case .redirectTo:
                return "/redirect-to"
            case .responseHeaders:
                return "/response-headers"
            case let .status(code):
                return "/status/\(code)"
            case let .stream(count):
                return "/stream/\(count)"
            case .upload:
                return "/upload"
            case .xml:
                return "/xml"
            }
        }
    }

    enum Image: String {
        case jpeg
    }

    enum Compression: String {
        case brotli, gzip, deflate
    }

    static var get: Endpoint { method(.get) }

    static func basicAuth(forUser user: String = "user", password: String = "password") -> Endpoint {
        Endpoint(path: .basicAuth(username: user, password: password))
    }

    static func bytes(_ count: Int) -> Endpoint {
        Endpoint(path: .bytes(count: count))
    }

    static let cache: Endpoint = .init(path: .cache)

    static func chunked(_ count: Int) -> Endpoint {
        Endpoint(path: .chunked(count: count))
    }

    static func compression(_ compression: Compression) -> Endpoint {
        Endpoint(path: .compression(compression))
    }

    static var `default`: Endpoint { .get }

    static func delay(_ interval: Int) -> Endpoint {
        Endpoint(path: .delay(interval: interval))
    }

    static func digestAuth(forUser user: String = "user", password: String = "password") -> Endpoint {
        Endpoint(path: .digestAuth(username: user, password: password))
    }

    static func download(_ count: Int = 10_000, produceError: Bool = false) -> Endpoint {
        Endpoint(path: .download(count: count), queryItems: [.init(name: "shouldProduceError",
                                                                   value: "\(produceError)")])
    }

    static func hiddenBasicAuth(forUser user: String = "user", password: String = "password") -> Endpoint {
        Endpoint(path: .hiddenBasicAuth(username: user, password: password),
                 headers: [.authorization(username: user, password: password)])
    }

    static func image(_ type: Image) -> Endpoint {
        Endpoint(path: .image(type))
    }

    static var ip: Endpoint {
        Endpoint(path: .ip)
    }

    static func method(_ method: HTTPMethod) -> Endpoint {
        Endpoint(path: .method(method), method: method)
    }

    static func payloads(_ count: Int) -> Endpoint {
        Endpoint(path: .payloads(count: count))
    }

    static func redirect(_ count: Int) -> Endpoint {
        Endpoint(path: .redirect(count: count))
    }

    static func redirectTo(_ url: String, code: Int? = nil) -> Endpoint {
        var items = [URLQueryItem(name: "url", value: url)]
        items = code.map { items + [.init(name: "statusCode", value: "\($0)")] } ?? items

        return Endpoint(path: .redirectTo, queryItems: items)
    }

    static func redirectTo(_ endpoint: Endpoint, code: Int? = nil) -> Endpoint {
        var items = [URLQueryItem(name: "url", value: endpoint.url.absoluteString)]
        items = code.map { items + [.init(name: "statusCode", value: "\($0)")] } ?? items

        return Endpoint(path: .redirectTo, queryItems: items)
    }

    static var responseHeaders: Endpoint {
        Endpoint(path: .responseHeaders)
    }

    static func status(_ code: Int) -> Endpoint {
        Endpoint(path: .status(code))
    }

    static func stream(_ count: Int) -> Endpoint {
        Endpoint(path: .stream(count: count))
    }

    static let upload: Endpoint = .init(path: .upload, method: .post, headers: [.contentType("application/octet-stream")])

    static var xml: Endpoint {
        Endpoint(path: .xml, headers: [.contentType("application/xml")])
    }

    var scheme = Scheme.http
    var port: Int { host.port(for: scheme) }
    var host = Host.localhost
    var path = Path.method(.get)
    var method: HTTPMethod = .get
    var headers: HTTPHeaders = .init()
    
    var timeout: TimeInterval = 60
    var queryItems: [URLQueryItem] = []
    var cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy // 这里控制了, 本次请求实际上应该使用缓存与否. 

    func modifying<T>(_ keyPath: WritableKeyPath<Endpoint, T>, to value: T) -> Endpoint {
        var copy = self
        copy[keyPath: keyPath] = value
        return copy
    }
}

/*
 Endpoint 是一个数据类. 在这个数据类里面, 实现各种协议.
 各种协议的结合, 实现了最终, 数据类到 URLRequest 类的过渡. 
 */
extension Endpoint: URLRequestConvertible {
    var urlRequest: URLRequest { try! asURLRequest() }

    // 最终, 是使用这个方法, 进行真正的 Request 的创建.
    func asURLRequest() throws -> URLRequest {
        var request = try URLRequest(url: asURL())
        request.method = method
        request.headers = headers
        request.timeoutInterval = timeout
        request.cachePolicy = cachePolicy

        return request
    }
}

extension Endpoint: URLConvertible {
    var url: URL { try! asURL() }

    func asURL() throws -> URL {
        var components = URLComponents()
        components.scheme = scheme.rawValue
        components.port = port
        components.host = host.rawValue
        components.path = path.string

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        return try components.asURL()
    }
}

extension Session {
    func request(_ endpoint: Endpoint,
                 parameters: Parameters? = nil,
                 encoding: ParameterEncoding = URLEncoding.default,
                 headers: HTTPHeaders? = nil,
                 interceptor: RequestInterceptor? = nil,
                 requestModifier: RequestModifier? = nil) -> DataRequest {
        request(endpoint as URLConvertible,
                method: endpoint.method,
                parameters: parameters,
                encoding: encoding,
                headers: headers,
                interceptor: interceptor,
                requestModifier: requestModifier)
    }

    func request<Parameters: Encodable>(_ endpoint: Endpoint,
                                        parameters: Parameters? = nil,
                                        encoder: ParameterEncoder = URLEncodedFormParameterEncoder.default,
                                        headers: HTTPHeaders? = nil,
                                        interceptor: RequestInterceptor? = nil,
                                        requestModifier: RequestModifier? = nil) -> DataRequest {
        request(endpoint as URLConvertible,
                method: endpoint.method,
                parameters: parameters,
                encoder: encoder,
                headers: headers,
                interceptor: interceptor,
                requestModifier: requestModifier)
    }

    func request(_ endpoint: Endpoint, interceptor: RequestInterceptor? = nil) -> DataRequest {
        request(endpoint as URLRequestConvertible, interceptor: interceptor)
    }

    func streamRequest(_ endpoint: Endpoint,
                       headers: HTTPHeaders? = nil,
                       automaticallyCancelOnStreamError: Bool = false,
                       interceptor: RequestInterceptor? = nil,
                       requestModifier: RequestModifier? = nil) -> DataStreamRequest {
        streamRequest(endpoint as URLConvertible,
                      method: endpoint.method,
                      headers: headers,
                      automaticallyCancelOnStreamError: automaticallyCancelOnStreamError,
                      interceptor: interceptor,
                      requestModifier: requestModifier)
    }

    func streamRequest(_ endpoint: Endpoint,
                       automaticallyCancelOnStreamError: Bool = false,
                       interceptor: RequestInterceptor? = nil) -> DataStreamRequest {
        streamRequest(endpoint as URLRequestConvertible,
                      automaticallyCancelOnStreamError: automaticallyCancelOnStreamError,
                      interceptor: interceptor)
    }

    func download<Parameters: Encodable>(_ endpoint: Endpoint,
                                         parameters: Parameters? = nil,
                                         encoder: ParameterEncoder = URLEncodedFormParameterEncoder.default,
                                         headers: HTTPHeaders? = nil,
                                         interceptor: RequestInterceptor? = nil,
                                         requestModifier: RequestModifier? = nil,
                                         to destination: DownloadRequest.Destination? = nil) -> DownloadRequest {
        download(endpoint as URLConvertible,
                 method: endpoint.method,
                 parameters: parameters,
                 encoder: encoder,
                 headers: headers,
                 interceptor: interceptor,
                 requestModifier: requestModifier,
                 to: destination)
    }

    func download(_ endpoint: Endpoint,
                  parameters: Parameters? = nil,
                  encoding: ParameterEncoding = URLEncoding.default,
                  headers: HTTPHeaders? = nil,
                  interceptor: RequestInterceptor? = nil,
                  requestModifier: RequestModifier? = nil,
                  to destination: DownloadRequest.Destination? = nil) -> DownloadRequest {
        download(endpoint as URLConvertible,
                 method: endpoint.method,
                 parameters: parameters,
                 encoding: encoding,
                 headers: headers,
                 interceptor: interceptor,
                 requestModifier: requestModifier,
                 to: destination)
    }

    func download(_ endpoint: Endpoint,
                  interceptor: RequestInterceptor? = nil,
                  to destination: DownloadRequest.Destination? = nil) -> DownloadRequest {
        download(endpoint as URLRequestConvertible, interceptor: interceptor, to: destination)
    }

    func upload(_ data: Data,
                to endpoint: Endpoint,
                headers: HTTPHeaders? = nil,
                interceptor: RequestInterceptor? = nil,
                fileManager: FileManager = .default,
                requestModifier: RequestModifier? = nil) -> UploadRequest {
        upload(data, to: endpoint as URLConvertible,
               method: endpoint.method,
               headers: headers,
               interceptor: interceptor,
               fileManager: fileManager,
               requestModifier: requestModifier)
    }
}

extension Data {
    var asString: String {
        String(decoding: self, as: UTF8.self)
    }

    func asJSONObject() throws -> Any {
        try JSONSerialization.jsonObject(with: self, options: .allowFragments)
    }
}

struct TestResponse: Decodable {
    let headers: [String: String]
    let origin: String
    let url: String?
    let data: String?
    let form: [String: String]?
    let args: [String: String]?
}

struct TestParameters: Encodable {
    static let `default` = TestParameters(property: "property")

    let property: String
}

struct UploadResponse: Decodable {
    let bytes: Int
}
