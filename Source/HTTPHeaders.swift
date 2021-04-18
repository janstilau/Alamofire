import Foundation

/// An order-preserving and case-insensitive representation of HTTP headers.
// 在 OC 时代, 这其实就是一个 Dict.
public struct HTTPHeaders {
    private var headers: [HTTPHeader] = []
    
    public init() {}
    
    /// Creates an instance from an array of `HTTPHeader`s. Duplicate case-insensitive names are collapsed into the last
    /// name and value encountered.
    public init(_ headers: [HTTPHeader]) {
        self.init()
        headers.forEach { update($0) }
    }
    
    /// Creates an instance from a `[String: String]`. Duplicate case-insensitive names are collapsed into the last name
    /// and value encountered.
    public init(_ dictionary: [String: String]) {
        self.init()
        
        dictionary.forEach { update(HTTPHeader(name: $0.key, value: $0.value)) }
    }
    
    /// Case-insensitively updates or appends an `HTTPHeader` into the instance using the provided `name` and `value`.
    ///
    /// - Parameters:
    ///   - name:  The `HTTPHeader` name.
    ///   - value: The `HTTPHeader value.
    public mutating func add(name: String, value: String) {
        update(HTTPHeader(name: name, value: value))
    }
    
    /// Case-insensitively updates or appends the provided `HTTPHeader` into the instance.
    ///
    /// - Parameter header: The `HTTPHeader` to update or append.
    public mutating func add(_ header: HTTPHeader) {
        update(header)
    }
    
    /// Case-insensitively updates or appends an `HTTPHeader` into the instance using the provided `name` and `value`.
    ///
    /// - Parameters:
    ///   - name:  The `HTTPHeader` name.
    ///   - value: The `HTTPHeader value.
    public mutating func update(name: String, value: String) {
        update(HTTPHeader(name: name, value: value))
    }
    
    // 一个核心方法, 大多数更新内容, 都是建立在这个方法之上的
    // 先查找, 如果有就替换 value, 如果没有, 就插入.
    public mutating func update(_ header: HTTPHeader) {
        guard let index = headers.index(of: header.name) else {
            headers.append(header)
            return
        }
        headers.replaceSubrange(index...index, with: [header])
    }
    
    public mutating func remove(name: String) {
        guard let index = headers.index(of: name) else { return }
        headers.remove(at: index)
    }
    
    /// Sort the current instance by header name, case insensitively.
    public mutating func sort() {
        headers.sort { $0.name.lowercased() < $1.name.lowercased() }
    }
    
    /// Returns an instance sorted by header name.
    ///
    /// - Returns: A copy of the current instance sorted by name.
    public func sorted() -> HTTPHeaders {
        var headers = self
        headers.sort()
        
        return headers
    }
    
    /// Case-insensitively find a header's value by name.
    ///
    /// - Parameter name: The name of the header to search for, case-insensitively.
    ///
    /// - Returns:        The value of header, if it exists.
    public func value(for name: String) -> String? {
        guard let index = headers.index(of: name) else { return nil }
        
        return headers[index].value
    }
    
    /// Case-insensitively access the header with the given name.
    ///
    /// - Parameter name: The name of the header.
    public subscript(_ name: String) -> String? {
        get { value(for: name) }
        set {
            if let value = newValue {
                update(name: name, value: value)
            } else {
                remove(name: name)
            }
        }
    }
    
    /// The dictionary representation of all headers.
    ///
    /// This representation does not preserve the current order of the instance.
    public var dictionary: [String: String] {
        let namesAndValues = headers.map { ($0.name, $0.value) }
        
        return Dictionary(namesAndValues, uniquingKeysWith: { _, last in last })
    }
}

// 实现了这个方法, 其实也就可以和 Dict 一个用法了.
extension HTTPHeaders: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, String)...) {
        self.init()
        elements.forEach { update(name: $0.0, value: $0.1) }
    }
}

extension HTTPHeaders: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: HTTPHeader...) {
        self.init(elements)
    }
}

// 实现了 Sequence 协议.
extension HTTPHeaders: Sequence {
    public func makeIterator() -> IndexingIterator<[HTTPHeader]> {
        headers.makeIterator()
    }
}

extension HTTPHeaders: Collection {
    public var startIndex: Int {
        headers.startIndex
    }
    
    public var endIndex: Int {
        headers.endIndex
    }
    
    public subscript(position: Int) -> HTTPHeader {
        headers[position]
    }
    
    public func index(after i: Int) -> Int {
        headers.index(after: i)
    }
}

extension HTTPHeaders: CustomStringConvertible {
    public var description: String {
        headers.map { $0.description }
            .joined(separator: "\n")
    }
}

// MARK: - HTTPHeader

// 一个特殊的类型, 来代表 HTTPHeader. 其实就是 key value 的 字符串映射.
// 这个类更加重要的, 应该是 static 所表示的各种特殊 key.
// 专门定义这样的一个类, 就让那些特殊的 httpHeader 生成有了位置.
public struct HTTPHeader: Hashable {
    /// Name of the header.
    public let name: String
    /// Value of the header.
    public let value: String
    public init(name: String, value: String) {
        self.name = name
        self.value = value
    }
}

extension HTTPHeader: CustomStringConvertible {
    public var description: String {
        "\(name): \(value)"
    }
}

extension HTTPHeader {
    public static func accept(_ value: String) -> HTTPHeader {
        HTTPHeader(name: "Accept", value: value)
    }
    public static func acceptCharset(_ value: String) -> HTTPHeader {
        HTTPHeader(name: "Accept-Charset", value: value)
    }
    public static func acceptLanguage(_ value: String) -> HTTPHeader {
        HTTPHeader(name: "Accept-Language", value: value)
    }
    public static func acceptEncoding(_ value: String) -> HTTPHeader {
        HTTPHeader(name: "Accept-Encoding", value: value)
    }
    public static func authorization(username: String, password: String) -> HTTPHeader {
        let credential = Data("\(username):\(password)".utf8).base64EncodedString()
        return authorization("Basic \(credential)")
    }
    public static func authorization(bearerToken: String) -> HTTPHeader {
        authorization("Bearer \(bearerToken)")
    }
    public static func authorization(_ value: String) -> HTTPHeader {
        HTTPHeader(name: "Authorization", value: value)
    }
    public static func contentDisposition(_ value: String) -> HTTPHeader {
        HTTPHeader(name: "Content-Disposition", value: value)
    }
    public static func contentType(_ value: String) -> HTTPHeader {
        HTTPHeader(name: "Content-Type", value: value)
    }
    public static func userAgent(_ value: String) -> HTTPHeader {
        HTTPHeader(name: "User-Agent", value: value)
    }
}

// Array 为 HTTPHeader 添加的专门根据 name 查找的方法.
extension Array where Element == HTTPHeader {
    func index(of name: String) -> Int? {
        let lowercasedName = name.lowercased()
        return firstIndex { $0.name.lowercased() == lowercasedName }
    }
}

// MARK: - Defaults

extension HTTPHeaders {
    /// The default set of `HTTPHeaders` used by Alamofire. Includes `Accept-Encoding`, `Accept-Language`, and
    /// `User-Agent`.
    public static let `default`: HTTPHeaders = [.defaultAcceptEncoding,
                                                .defaultAcceptLanguage,
                                                .defaultUserAgent]
}

// 几个默认的值, 使用的是 static let 进行懒加载
extension HTTPHeader {
    /// Returns Alamofire's default `Accept-Encoding` header, appropriate for the encodings supported by particular OS
    /// versions.
    ///
    /// See the [Accept-Encoding HTTP header documentation](https://tools.ietf.org/html/rfc7230#section-4.2.3) .
    public static let defaultAcceptEncoding: HTTPHeader = {
        let encodings: [String]
        if #available(iOS 11.0, macOS 10.13, tvOS 11.0, watchOS 4.0, *) {
            encodings = ["br", "gzip", "deflate"]
        } else {
            encodings = ["gzip", "deflate"]
        }
        return .acceptEncoding(encodings.qualityEncoded())
    }()
    
    /// Returns Alamofire's default `Accept-Language` header, generated by querying `Locale` for the user's
    /// `preferredLanguages`.
    ///
    /// See the [Accept-Language HTTP header documentation](https://tools.ietf.org/html/rfc7231#section-5.3.5).
    public static let defaultAcceptLanguage: HTTPHeader = {
        .acceptLanguage(Locale.preferredLanguages.prefix(6).qualityEncoded())
    }()
    
    /// Returns Alamofire's default `User-Agent` header.
    ///
    /// See the [User-Agent header documentation](https://tools.ietf.org/html/rfc7231#section-5.5.3).
    ///
    /// Example: `iOS Example/1.0 (org.alamofire.iOS-Example; build:1; iOS 13.0.0) Alamofire/5.0.0`
    public static let defaultUserAgent: HTTPHeader = {
        let info = Bundle.main.infoDictionary
        let executable = (info?[kCFBundleExecutableKey as String] as? String) ??
            (ProcessInfo.processInfo.arguments.first?.split(separator: "/").last.map(String.init)) ??
            "Unknown"
        let bundle = info?[kCFBundleIdentifierKey as String] as? String ?? "Unknown"
        let appVersion = info?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let appBuild = info?[kCFBundleVersionKey as String] as? String ?? "Unknown"
        
        let osNameVersion: String = {
            let version = ProcessInfo.processInfo.operatingSystemVersion
            let versionString = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
            let osName: String = {
                #if os(iOS)
                #if targetEnvironment(macCatalyst)
                return "macOS(Catalyst)"
                #else
                return "iOS"
                #endif
                #elseif os(watchOS)
                return "watchOS"
                #elseif os(tvOS)
                return "tvOS"
                #elseif os(macOS)
                return "macOS"
                #elseif os(Linux)
                return "Linux"
                #elseif os(Windows)
                return "Windows"
                #else
                return "Unknown"
                #endif
            }()
            
            return "\(osName) \(versionString)"
        }()
        
        let alamofireVersion = "Alamofire/\(version)"
        
        let userAgent = "\(executable)/\(appVersion) (\(bundle); build:\(appBuild); \(osNameVersion)) \(alamofireVersion)"
        return .userAgent(userAgent)
    }()
}

extension Collection where Element == String {
    func qualityEncoded() -> String {
        enumerated().map { index, encoding in
            let quality = 1.0 - (Double(index) * 0.1)
            return "\(encoding);q=\(quality)"
        }.joined(separator: ", ")
    }
}

// MARK: - System Type Extensions

extension URLRequest {
    /// Returns `allHTTPHeaderFields` as `HTTPHeaders`.
    public var headers: HTTPHeaders {
        get { allHTTPHeaderFields.map(HTTPHeaders.init) ?? HTTPHeaders() }
        set { allHTTPHeaderFields = newValue.dictionary }
    }
}

extension HTTPURLResponse {
    /// Returns `allHeaderFields` as `HTTPHeaders`.
    public var headers: HTTPHeaders {
        (allHeaderFields as? [String: String]).map(HTTPHeaders.init) ?? HTTPHeaders()
    }
}

extension URLSessionConfiguration {
    /// Returns `httpAdditionalHeaders` as `HTTPHeaders`.
    public var headers: HTTPHeaders {
        get { (httpAdditionalHeaders as? [String: String]).map(HTTPHeaders.init) ?? HTTPHeaders() }
        set { httpAdditionalHeaders = newValue.dictionary }
    }
}
