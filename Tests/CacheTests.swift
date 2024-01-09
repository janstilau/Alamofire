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
    }
    
    // MARK: - Properties
    
    var urlCache: URLCache!
    var manager: Session!
    
    var requests: [CacheControl: URLRequest] = [:] // 这里面, 存储的是各缓存策略发起的请求.
    var timestamps: [CacheControl: String] = [:] // 这里面, 存储的是响应时间的时间点.
    
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
        timestamps.removeAll()
        
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
        // 这里使用了 dispatchGroup, 进行了线程的执行控制.
        for cacheControl in CacheControl.allCases {
            dispatchGroup.enter()
            
            let request = startRequest(cacheControl: cacheControl,
                                       queue: serialQueue,
                                       completion: { _, response in
                let timestamp = response!.headers["Date"]
                self.timestamps[cacheControl] = timestamp
                
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
    
    private func verifyResponse(_ response: HTTPURLResponse?, forCacheControl cacheControl: CacheControl, isCachedResponse: Bool) {
        guard let cachedResponseTimestamp = timestamps[cacheControl] else {
            XCTFail("cached response timestamp should not be nil")
            return
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
        
        // When
        let publicResponse = urlCache.cachedResponse(for: publicRequest)
        let privateResponse = urlCache.cachedResponse(for: privateRequest)
        let maxAgeNonExpiredResponse = urlCache.cachedResponse(for: maxAgeNonExpiredRequest)
        let maxAgeExpiredResponse = urlCache.cachedResponse(for: maxAgeExpiredRequest)
        let noCacheResponse = urlCache.cachedResponse(for: noCacheRequest)
        let noStoreResponse = urlCache.cachedResponse(for: noStoreRequest)
        
        // Then
        XCTAssertNotNil(publicResponse, "\(CacheControl.publicControl) response should not be nil")
        XCTAssertNotNil(privateResponse, "\(CacheControl.privateControl) response should not be nil")
        XCTAssertNotNil(maxAgeNonExpiredResponse, "\(CacheControl.maxAgeNonExpired) response should not be nil")
        XCTAssertNotNil(maxAgeExpiredResponse, "\(CacheControl.maxAgeExpired) response should not be nil")
        XCTAssertNotNil(noCacheResponse, "\(CacheControl.noCache) response should not be nil")
        XCTAssertNil(noStoreResponse, "\(CacheControl.noStore) response should be nil")
    }
    
    func testDefaultCachePolicy() {
        let cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy
        
        // 使用对应的缓存管理策略对应的 URL 发送网络请求, 然后判断, 响应是否是从 URLCache 里面获取到的.
        // 从这里来看, 应该是只有 maxAgeExpired 这种方式, 才会使用到缓存中的响应
        executeTest(cachePolicy: cachePolicy, cacheControl: .publicControl, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: .privateControl, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: .maxAgeNonExpired, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: .maxAgeExpired, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: .noCache, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: .noStore, shouldReturnCachedResponse: false)
    }
    
    func testIgnoreLocalCacheDataPolicy() {
        let cachePolicy: URLRequest.CachePolicy = .reloadIgnoringLocalCacheData
        
        executeTest(cachePolicy: cachePolicy, cacheControl: .publicControl, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: .privateControl, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: .maxAgeNonExpired, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: .maxAgeExpired, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: .noCache, shouldReturnCachedResponse: false)
        executeTest(cachePolicy: cachePolicy, cacheControl: .noStore, shouldReturnCachedResponse: false)
    }
    
    func testUseLocalCacheDataIfExistsOtherwiseLoadFromNetworkPolicy() {
        let cachePolicy: URLRequest.CachePolicy = .returnCacheDataElseLoad
        
        executeTest(cachePolicy: cachePolicy, cacheControl: .publicControl, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: .privateControl, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: .maxAgeNonExpired, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: .maxAgeExpired, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: .noCache, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: .noStore, shouldReturnCachedResponse: false)
    }
    
    func testUseLocalCacheDataAndDontLoadFromNetworkPolicy() {
        let cachePolicy: URLRequest.CachePolicy = .returnCacheDataDontLoad
        
        executeTest(cachePolicy: cachePolicy, cacheControl: .publicControl, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: .privateControl, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: .maxAgeNonExpired, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: .maxAgeExpired, shouldReturnCachedResponse: true)
        executeTest(cachePolicy: cachePolicy, cacheControl: .noCache, shouldReturnCachedResponse: true)
        
        // Given
        let requestDidFinish = expectation(description: "don't load from network request finished")
        var response: HTTPURLResponse?
        
        // When
        startRequest(cacheControl: .noStore, cachePolicy: cachePolicy) { _, responseResponse in
            response = responseResponse
            requestDidFinish.fulfill()
        }
        
        waitForExpectations(timeout: timeout)
        
        // Then
        XCTAssertNil(response, "response should be nil")
    }
}
