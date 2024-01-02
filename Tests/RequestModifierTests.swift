import Alamofire
import XCTest

final class RequestModifierTests: BaseTestCase {
    // MARK: - DataRequest

    func testThatDataRequestsCanHaveCustomTimeoutValueSet() {
        // Given
        let completed = expectation(description: "request completed")
        let modified = expectation(description: "request should be modified")
        var response: AFDataResponse<Data?>?

        // When
        // 使用了 modify 对 request 进行了修改.
        // 设置了超时时间, 然后服务器会一秒后返回.
        AF.request(.delay(1)) { $0.timeoutInterval = 0.01; modified.fulfill() }
            .response { response = $0; completed.fulfill() }

        waitForExpectations(timeout: timeout)

        // Then
        // 最后验证, 是超时的错误. 错误的原因, 是 error 里面进行的记录.
        XCTAssertEqual((response?.error?.underlyingError as? URLError)?.code, .timedOut)
    }

    func testThatDataRequestsCallRequestModifiersOnRetry() {
        // Given
        let inspector = InspectorInterceptor(RetryPolicy(retryLimit: 1, exponentialBackoffScale: 0))
        let session = Session(interceptor: inspector)
        
        let completed = expectation(description: "request completed")
        let modified = expectation(description: "request should be modified twice")
        modified.expectedFulfillmentCount = 2
        var response: AFDataResponse<Data?>?

        // When
        session.request(.delay(1)) { $0.timeoutInterval = 0.01; modified.fulfill() }
            .response { response = $0; completed.fulfill() }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual((response?.error?.underlyingError as? URLError)?.code, .timedOut)
        XCTAssertEqual(inspector.retryCalledCount, 2)
    }

    // MARK: - UploadRequest

    func testThatUploadRequestsCanHaveCustomTimeoutValueSet() {
        // Given
        let endpoint = Endpoint.delay(1).modifying(\.method, to: .post)
        let data = Data("data".utf8)
        let completed = expectation(description: "request completed")
        let modified = expectation(description: "request should be modified")
        var response: AFDataResponse<Data?>?

        // When
        AF.upload(data, to: endpoint) { $0.timeoutInterval = 0.01; modified.fulfill() }
            .response { response = $0; completed.fulfill() }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual((response?.error?.underlyingError as? URLError)?.code, .timedOut)
    }

    func testThatUploadRequestsCallRequestModifiersOnRetry() {
        // Given
        let endpoint = Endpoint.delay(1).modifying(\.method, to: .post)
        let data = Data("data".utf8)
        let policy = RetryPolicy(retryLimit: 1, exponentialBackoffScale: 0, retryableHTTPMethods: [.post])
        let inspector = InspectorInterceptor(policy)
        let session = Session(interceptor: inspector)
        let completed = expectation(description: "request completed")
        let modified = expectation(description: "request should be modified twice")
        modified.expectedFulfillmentCount = 2
        var response: AFDataResponse<Data?>?

        // When
        session.upload(data, to: endpoint) { $0.timeoutInterval = 0.01; modified.fulfill() }
            .response { response = $0; completed.fulfill() }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual((response?.error?.underlyingError as? URLError)?.code, .timedOut)
        XCTAssertEqual(inspector.retryCalledCount, 2)
    }

    // MARK: - DownloadRequest

    func testThatDownloadRequestsCanHaveCustomTimeoutValueSet() {
        // Given
        let url = Endpoint.delay(1).url
        let completed = expectation(description: "request completed")
        let modified = expectation(description: "request should be modified")
        var response: AFDownloadResponse<URL?>?

        // When
        AF.download(url, requestModifier: { $0.timeoutInterval = 0.01; modified.fulfill() })
            .response { response = $0; completed.fulfill() }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual((response?.error?.underlyingError as? URLError)?.code, .timedOut)
    }

    func testThatDownloadRequestsCallRequestModifiersOnRetry() {
        // Given
        let inspector = InspectorInterceptor(RetryPolicy(retryLimit: 1, exponentialBackoffScale: 0))
        let session = Session(interceptor: inspector)
        let completed = expectation(description: "request completed")
        let modified = expectation(description: "request should be modified twice")
        modified.expectedFulfillmentCount = 2
        var response: AFDownloadResponse<URL?>?

        // When
        session.download(.delay(1), requestModifier: { $0.timeoutInterval = 0.01; modified.fulfill() })
            .response { response = $0; completed.fulfill() }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual((response?.error?.underlyingError as? URLError)?.code, .timedOut)
        XCTAssertEqual(inspector.retryCalledCount, 2)
    }

    // MARK: - DataStreamRequest

    func testThatDataStreamRequestsCanHaveCustomTimeoutValueSet() {
        // Given
        let completed = expectation(description: "request completed")
        let modified = expectation(description: "request should be modified")
        var response: DataStreamRequest.Completion?

        // When
        AF.streamRequest(.delay(1)) { $0.timeoutInterval = 0.01; modified.fulfill() }
            .responseStream { stream in
                guard case let .complete(completion) = stream.event else { return }

                response = completion
                completed.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual((response?.error?.underlyingError as? URLError)?.code, .timedOut)
    }

    func testThatDataStreamRequestsCallRequestModifiersOnRetry() {
        // Given
        let inspector = InspectorInterceptor(RetryPolicy(retryLimit: 1, exponentialBackoffScale: 0))
        let session = Session(interceptor: inspector)
        let completed = expectation(description: "request completed")
        let modified = expectation(description: "request should be modified twice")
        modified.expectedFulfillmentCount = 2
        var response: DataStreamRequest.Completion?

        // When
        session.streamRequest(.delay(1)) { $0.timeoutInterval = 0.01; modified.fulfill() }
            .responseStream { stream in
                guard case let .complete(completion) = stream.event else { return }

                response = completion
                completed.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual((response?.error?.underlyingError as? URLError)?.code, .timedOut)
        XCTAssertEqual(inspector.retryCalledCount, 2)
    }
}
