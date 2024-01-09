import Alamofire
import Foundation
import XCTest

final class CachedResponseHandlerTestCase: BaseTestCase {
    // MARK: Tests - Per Request

    /*
     因为这是一个异步的机制, 所以所有的都是说, 在 expection 中进行等待, 在之后来判断相关的代码是否按照预料的进行执行.
     */
    func testThatRequestCachedResponseHandlerCanCacheResponse() {
        // Given
        let session = session()

        var response: DataResponse<Data?, AFError>?
        let expectation = expectation(description: "Request should cache response")

        // When
        // 使用 cacheResponse, 就是专门配置了这个 Request 应该使用什么样的策略.
        // 这里策略就是存储 Cache.
        // 最后验证的时候, 就是验证这个进行了存储.
        let request = session.request(.default).cacheResponse(using: ResponseCacher.cache).response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(response?.result.isSuccess, true)
        XCTAssertTrue(session.cachedResponseExists(for: request))
    }

    func testThatRequestCachedResponseHandlerCanNotCacheResponse() {
        // Given
        let session = session()

        var response: DataResponse<Data?, AFError>?
        let expectation = expectation(description: "Request should not cache response")

        // When
        // 在这里, 明确的规定了, 这个 Request 不进行存储, 所以最后验证的时候, 就是验证不存在.
        let request = session.request(.default).cacheResponse(using: ResponseCacher.doNotCache).response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(response?.result.isSuccess, true)
        XCTAssertFalse(session.cachedResponseExists(for: request))
    }

    func testThatRequestCachedResponseHandlerCanModifyCacheResponse() {
        // Given
        let session = session()

        var response: DataResponse<Data?, AFError>?
        let expectation = expectation(description: "Request should cache response")

        // When
        let cacher = ResponseCacher(behavior: .modify { _, response in
            CachedURLResponse(response: response.response,
                              data: response.data,
                              userInfo: ["key": "value"],
                              storagePolicy: .allowed)
        })

        // 当需要缓存的时候, 会调用 ResponseCacher 中存储的闭包, 对缓存进行修改.
        let request = session.request(.default).cacheResponse(using: cacher).response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(response?.result.isSuccess, true)
        XCTAssertTrue(session.cachedResponseExists(for: request))
        XCTAssertEqual(session.cachedResponse(for: request)?.userInfo?["key"] as? String, "value")
    }

    // MARK: Tests - Per Session

    func testThatSessionCachedResponseHandlerCanCacheResponse() {
        // Given
        let session = session(using: ResponseCacher.cache)

        var response: DataResponse<Data?, AFError>?
        let expectation = expectation(description: "Request should cache response")

        // When
        // 如果, 什么都没有做, 那么其实会进行缓存的.
        let request = session.request(.default).response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(response?.result.isSuccess, true)
        XCTAssertTrue(session.cachedResponseExists(for: request))
    }

    // Session 设置了不进行缓存, 如果单个 Request 不进行设置的话, 就使用 Session 中配置的值.
    func testThatSessionCachedResponseHandlerCanNotCacheResponse() {
        // Given
        let session = session(using: ResponseCacher.doNotCache)

        var response: DataResponse<Data?, AFError>?
        let expectation = expectation(description: "Request should not cache response")

        // When
        let request = session.request(.default).cacheResponse(using: ResponseCacher.doNotCache).response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(response?.result.isSuccess, true)
        XCTAssertFalse(session.cachedResponseExists(for: request))
    }

    // Session 设置了 Modify 的配置.
    func testThatSessionCachedResponseHandlerCanModifyCacheResponse() {
        // Given
        let cacher = ResponseCacher(behavior: .modify { _, response in
            CachedURLResponse(response: response.response,
                              data: response.data,
                              userInfo: ["key": "value"],
                              storagePolicy: .allowed)
        })

        let session = session(using: cacher)

        var response: DataResponse<Data?, AFError>?
        let expectation = expectation(description: "Request should cache response")

        // When
        let request = session.request(.default).cacheResponse(using: cacher).response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(response?.result.isSuccess, true)
        XCTAssertTrue(session.cachedResponseExists(for: request))
        XCTAssertEqual(session.cachedResponse(for: request)?.userInfo?["key"] as? String, "value")
    }

    // MARK: Tests - Per Request Prioritization
    // 优先使用 Request 里面, 设置的 ResponserCacher
    func testThatRequestCachedResponseHandlerIsPrioritizedOverSessionCachedResponseHandler() {
        // Given
        let session = session(using: ResponseCacher.cache)

        var response: DataResponse<Data?, AFError>?
        let expectation = expectation(description: "Request should cache response")

        // When
        let request = session.request(.default).cacheResponse(using: ResponseCacher.doNotCache).response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual(response?.result.isSuccess, true)
        XCTAssertFalse(session.cachedResponseExists(for: request))
    }

    // MARK: Private - Test Helpers

    private func session(using handler: CachedResponseHandler? = nil) -> Session {
        let configuration = URLSessionConfiguration.af.default
        let capacity = 100_000_000
        let cache: URLCache
        
        #if targetEnvironment(macCatalyst)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        cache = URLCache(memoryCapacity: capacity, diskCapacity: capacity, directory: directory)
        #else
        let directory = (NSTemporaryDirectory() as NSString).appendingPathComponent(UUID().uuidString)
        cache = URLCache(memoryCapacity: capacity, diskCapacity: capacity, diskPath: directory)
        #endif
        
        configuration.urlCache = cache

        return Session(configuration: configuration, cachedResponseHandler: handler)
    }
}

final class StaticCachedResponseHandlerTests: BaseTestCase {
    func takeCachedResponseHandler(_ handler: CachedResponseHandler) {
        _ = handler
    }

    func testThatCacheResponseCacherCanBeCreatedStaticallyFromProtocol() {
        // Given, When, Then
        takeCachedResponseHandler(.cache)
    }

    func testThatDoNotCacheResponseCacherCanBeCreatedStaticallyFromProtocol() {
        // Given, When, Then
        takeCachedResponseHandler(.doNotCache)
    }

    func testThatModifyResponseCacherCanBeCreatedStaticallyFromProtocol() {
        // Given, When, Then
        takeCachedResponseHandler(.modify { _, _ in nil })
    }
}

// MARK: -

extension Session {
    fileprivate func cachedResponse(for request: Request) -> CachedURLResponse? {
        guard let urlRequest = request.request else { return nil }
        return session.configuration.urlCache?.cachedResponse(for: urlRequest)
    }

    fileprivate func cachedResponseExists(for request: Request) -> Bool {
        cachedResponse(for: request) != nil
    }
}
