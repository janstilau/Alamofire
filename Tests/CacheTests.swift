import Alamofire
import Foundation
import XCTest

/// This test case tests all implemented cache policies against various `Cache-Control` header values. These tests
/// are meant to cover the main cases of `Cache-Control` header usage, but are by no means exhaustive.
///
/// These tests work as follows:
///
/// - Set up an `URLCache`
/// - Set up an `Alamofire.Session`
/// - Execute requests for all `Cache-Control` header values to prime the `URLCache` with cached responses
/// - Start up a new test
/// - Execute another round of the same requests with a given `URLRequestCachePolicy`
/// - Verify whether the response came from the cache or from the network
///     - This is determined by whether the cached response timestamp matches the new response timestamp
///
/// For information about `Cache-Control` HTTP headers, please refer to RFC 2616 - Section 14.9.
///
/*
 从这个文件, 可以分析一下, URL Cache 在 URL Loading System 里面, 到底是如何进行的运转. 
 */
final class CacheTestCase: BaseTestCase {
    // MARK: -
    
    enum CacheControl: String, CaseIterable {
        case publicControl = "public"
        case privateControl = "private"
        case maxAgeNonExpired = "max-age=3600"
        case maxAgeExpired = "max-age=0"
        case noCache = "no-cache"
        case noStore = "no-store"
        
        case empty = "empty"
        case expireAlread = "expireAlread"
        case expireNextDay = "expireNextDay"
    }
    
    // MARK: - Properties
    
    var urlCache: URLCache!
    var manager: Session!
    
    var requests: [CacheControl: URLRequest] = [:] // 这里面, 存储的是各缓存策略发起的请求.
    var respTimestamps: [CacheControl: String] = [:] // 这里面, 存储的是响应时间的时间点.
    
    // MARK: - Setup and Teardown
    
    // 每次单元测试, 都会触发这里.
    override func setUp() {
        super.setUp()
        
        urlCache = {
            let capacity = 50 * 1024 * 1024 // MBs
#if targetEnvironment(macCatalyst)
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            return URLCache(memoryCapacity: capacity, diskCapacity: capacity, directory: directory)
#else
            let directory = (NSTemporaryDirectory() as NSString).appendingPathComponent(UUID().uuidString)
            return URLCache(memoryCapacity: capacity, diskCapacity: capacity, diskPath: directory)
#endif
        }()
        
        manager = {
            //这种写法要多用, let + 初始化封装. 结构更加清晰, 并且将初始化的地方封装, 防止修改.
            let configuration: URLSessionConfiguration = {
                let configuration = URLSessionConfiguration.default
                configuration.headers = HTTPHeaders.default
                configuration.requestCachePolicy = .useProtocolCachePolicy // 缓存的使用策略, 和 HTTP 协议的是一致的.
                configuration.urlCache = urlCache
                
                return configuration
            }()
            
            let manager = Session(configuration: configuration)
            return manager
        }()
        
        primeCachedResponses()
    }
    
    override func tearDown() {
        super.tearDown()
        
        requests.removeAll()
        respTimestamps.removeAll()
        
        urlCache.removeAllCachedResponses()
    }
    
    // MARK: - Cache Priming Methods
    
    /// Executes a request for all `Cache-Control` header values to load the response into the `URLCache`.
    ///
    /// - Note: This implementation leverages dispatch groups to execute all the requests. This ensures the cache
    ///         contains responses for all requests, properly aged from Firewalk. This allows the tests to distinguish
    ///         whether the subsequent responses come from the cache or the network based on the timestamp of the
    ///         response.
    private func primeCachedResponses() {
        let dispatchGroup = DispatchGroup()
        let serialQueue = DispatchQueue(label: "org.alamofire.cache-tests")
        
        // 这里触发了各种请求, 然后进行存储.
        // 这里使用了 dispatchGroup, 进行了线程的执行控制. 当所有的请求回来之后, 才会继续后续的逻辑.
        // dispatchGroup 是这种需要等待的代码, 经常使用的工具.
        for cacheControl in CacheControl.allCases {
            dispatchGroup.enter()
            
            let request = startRequest(cacheControl: cacheControl,
                                       queue: serialQueue,
                                       completion: { _, response in
                let timestamp = response!.headers["Date"]
                self.respTimestamps[cacheControl] = timestamp
                
                dispatchGroup.leave()
            })
            
            requests[cacheControl] = request
        }
        
        // Wait for all requests to complete
        _ = dispatchGroup.wait(timeout: .now() + timeout)
    }
    
    // MARK: - Request Helper Methods
    
    @discardableResult
    private func startRequest(cacheControl: CacheControl,
                              cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
                              queue: DispatchQueue = .main,
                              completion: @escaping (URLRequest?, HTTPURLResponse?) -> Void)
    -> URLRequest {
        let urlRequest = Endpoint(path: .cache,
                                  timeout: 30,
                                  queryItems: [.init(name: "Cache-Control", value: cacheControl.rawValue)],
                                  cachePolicy: cachePolicy).urlRequest
        let request = manager.request(urlRequest)
        
        request.response(queue: queue) { response in
            completion(response.request, response.response)
        }
        
        return urlRequest
    }
    
    // MARK: - Test Execution and Verification
    
    private func executeTest(cachePolicy: URLRequest.CachePolicy,
                             cacheControl: CacheControl,
                             shouldReturnCachedResponse: Bool) {
        // Given
        let requestDidFinish = expectation(description: "cache test request did finish")
        var response: HTTPURLResponse?
        
        // When
        startRequest(cacheControl: cacheControl, cachePolicy: cachePolicy) { _, responseResponse in
            response = responseResponse
            requestDidFinish.fulfill()
        }
        
        waitForExpectations(timeout: timeout)
        
        // Then
        verifyResponse(response, forCacheControl: cacheControl, isCachedResponse: shouldReturnCachedResponse)
    }
    
    // 如果是使用缓存, 那么获取到的 Response 应该和存储的是一样的.
    private func verifyResponse(_ response: HTTPURLResponse?, forCacheControl cacheControl: CacheControl, isCachedResponse: Bool) {
        guard let cachedResponseTimestamp = respTimestamps[cacheControl] else {
            XCTFail("cached response timestamp should not be nil")
            return
        }
        
        if cacheControl == .expireNextDay {
            print("expireNextDay")
        }
        if let response = response, let timestamp = response.headers["Date"] {
            if isCachedResponse {
                XCTAssertEqual(timestamp, cachedResponseTimestamp, "timestamps should be equal")
            } else {
                XCTAssertNotEqual(timestamp, cachedResponseTimestamp, "timestamps should not be equal")
            }
        } else {
            XCTFail("response should not be nil")
        }
    }
    
    // MARK: - Tests
    
    func testURLCacheContainsCachedResponsesForAllRequests() {
        // Given
        let publicRequest = requests[.publicControl]!
        let privateRequest = requests[.privateControl]!
        let maxAgeNonExpiredRequest = requests[.maxAgeNonExpired]!
        let maxAgeExpiredRequest = requests[.maxAgeExpired]!
        let noCacheRequest = requests[.noCache]!
        let noStoreRequest = requests[.noStore]!
        let emptyRequest = requests[.empty]!
        let expiredAlreadyRequest = requests[.expireAlread]!
        let expireNextDayRequest = requests[.expireNextDay]!
        
        // When
        let publicResponse = urlCache.cachedResponse(for: publicRequest)
        let privateResponse = urlCache.cachedResponse(for: privateRequest)
        let maxAgeNonExpiredResponse = urlCache.cachedResponse(for: maxAgeNonExpiredRequest)
        let maxAgeExpiredResponse = urlCache.cachedResponse(for: maxAgeExpiredRequest)
        let noCacheResponse = urlCache.cachedResponse(for: noCacheRequest)
        let noStoreResponse = urlCache.cachedResponse(for: noStoreRequest)
        let emptyResponse = urlCache.cachedResponse(for: emptyRequest)
        let expiredAlreadyResponse = urlCache.cachedResponse(for: expiredAlreadyRequest)
        let expireNextDayResponse = urlCache.cachedResponse(for: expireNextDayRequest)
        
        // Then
        XCTAssertNotNil(publicResponse, "\(CacheControl.publicControl) response should not be nil")
        XCTAssertNotNil(privateResponse, "\(CacheControl.privateControl) response should not be nil")
        XCTAssertNotNil(maxAgeNonExpiredResponse, "\(CacheControl.maxAgeNonExpired) response should not be nil")
        XCTAssertNotNil(maxAgeExpiredResponse, "\(CacheControl.maxAgeExpired) response should not be nil")
        XCTAssertNotNil(noCacheResponse, "\(CacheControl.noCache) response should not be nil")
        XCTAssertNil(noStoreResponse, "\(CacheControl.noStore) response should be nil")
        // empty 里面, 并没有相关的 Cache-Control 的协议头, 但是还是被缓存到了 urlCache 的内部.
        XCTAssertNotNil(emptyResponse, "\(CacheControl.empty) response should not be nil")
        
        XCTAssertNotNil(expiredAlreadyResponse, "\(CacheControl.expireAlread) response should not be nil")
        XCTAssertNotNil(expireNextDayResponse, "\(CacheControl.expireNextDay) response should not be nil")
        
        /*
         public: 这个指令允许响应被任何缓存（包括共享缓存和私有缓存）存储。因此，public 指令的响应通常会被缓存。
         private: 这个指令指定响应只能被私有缓存存储，如浏览器的本地缓存，而不是共享缓存（例如代理服务器）。private 指令的响应可以被缓存，但仅限于私有缓存。
         max-age: 这个指令指定了资源可以在本地缓存中保持新鲜的最大时间。如果 max-age 设置的时间还没有过期，响应就可以从缓存中获取，否则需要重新从服务器获取。
         max-age=3600 (非过期): 在指定的时间内，缓存是有效的，因此可以从缓存中获取响应。
         max-age=0 (已过期): 这意味着缓存立即过期，因此响应不应该从缓存中获取。
         no-cache: 这个指令并不是说不进行缓存，而是指在使用缓存的响应之前，必须先向原始服务器进行验证。因此，no-cache 响应可能会被存储在缓存中，但在每次使用之前都需要验证。
         no-store: 这是唯一明确指示不得对响应进行缓存的指令。no-store 响应不应该被任何形式的缓存所存储。
         */
    }
    
    func testDefaultCachePolicy() {
        let cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy
        
        // 使用 useProtocolCachePolicy 的这种方式, 只有明确的设置了 Cache-Control 的响应头, 并且还在有效期里面的 max-age=3600, 才会返回.
        executeTest(cachePolicy: cachePolicy, cacheControl: .publicControl, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: .privateControl, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: .maxAgeNonExpired, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: .maxAgeExpired, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: .noCache, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: .noStore, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: .empty, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: .expireAlread, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: .expireNextDay, shouldReturnCachedResponse: true)
        /*
         在您的测试用例中，使用的 URLRequest.CachePolicy 是 .useProtocolCachePolicy。这个缓存策略指示 URLSession 遵循 HTTP 协议的缓存控制头（如 Cache-Control 和 Expires）来决定是否使用缓存。这意味着缓存的使用将基于服务器返回的响应头。让我们分析一下您的测试用例：

         publicControl 和 privateControl：虽然 public 和 private 缓存控制头允许响应被缓存，但它们不保证立即从缓存中获取响应。这取决于响应的其他缓存控制头，如 max-age 或 Expires。如果这些头部没有指定或指定的缓存时间已过期，那么即使是 public 或 private 响应，也可能需要从服务器重新获取。
         maxAgeNonExpired：这个指令设置了一个尚未过期的 max-age，这意味着响应应该在指定时间内从缓存中获取，而不是重新从服务器请求。
         maxAgeExpired：即使设置了 max-age，如果指定的时间已过期，缓存不应该被使用，因此需要重新从服务器获取。
         noCache：即使响应可能被存储在缓存中，no-cache 指令要求每次使用缓存之前都必须向服务器重新验证，这通常意味着需要进行网络请求。
         noStore：这个指令明确指出不应缓存响应。因此，不会从缓存中获取这种响应。
         */
    }
    
    func testIgnoreLocalCacheDataPolicy() {
        let cachePolicy: URLRequest.CachePolicy = .reloadIgnoringLocalCacheData
        
        // 不管本地的缓存, 直接使用远端的数据.
        // 所以这里的响应的数据, 应该和事先存储的不是一个数据.
        executeTest(cachePolicy: cachePolicy, cacheControl: .publicControl, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: .privateControl, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: .maxAgeNonExpired, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: .maxAgeExpired, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: .noCache, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: .noStore, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: .empty, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: .expireAlread, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: .expireNextDay, shouldReturnCachedResponse: false)
    }
    
    func testUseLocalCacheDataIfExistsOtherwiseLoadFromNetworkPolicy() {
        let cachePolicy: URLRequest.CachePolicy = .returnCacheDataElseLoad
        
        // 优先缓存. 所以策略就是, 只要 URLCache 里面有值, 就用里面的.
        executeTest(cachePolicy: cachePolicy, cacheControl: .publicControl, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: .privateControl, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: .maxAgeNonExpired, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: .maxAgeExpired, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: .noCache, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: .noStore, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: .empty, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: .expireAlread, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: .expireNextDay, shouldReturnCachedResponse: true)
    }
    
    func testUseLocalCacheDataAndDontLoadFromNetworkPolicy() {
        let cachePolicy: URLRequest.CachePolicy = .returnCacheDataDontLoad
        
        /*
         只会使用缓存的, 所以有缓存的可以拿到数据.
         */
        executeTest(cachePolicy: cachePolicy, cacheControl: .publicControl, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: .privateControl, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: .maxAgeNonExpired, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: .maxAgeExpired, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: .noCache, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: .empty, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: .expireAlread, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: .expireNextDay, shouldReturnCachedResponse: true)
        // Given
        let requestDidFinish = expectation(description: "don't load from network request finished")
        var response: HTTPURLResponse?
        
        // When
        /*
         No-Store 的因为本地没有, 所以一直到最后, 就拿不到数据了. 
         */
        startRequest(cacheControl: .noStore, cachePolicy: cachePolicy) { _, responseResponse in
            response = responseResponse
            requestDidFinish.fulfill()
        }
        
        waitForExpectations(timeout: timeout)
        
        // Then
        XCTAssertNil(response, "response should be nil")
    }
}
