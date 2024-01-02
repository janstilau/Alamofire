import Alamofire
import Foundation
import XCTest

final class BasicAuthenticationTestCase: BaseTestCase {
    
    /*
     http://127.0.0.1:8080/basic-auth/user/password, NSErrorFailingURLKey=http://127.0.0.1:8080/basic-auth/user/password
     */
    // 对于这种测试用例, 需要起一个本地的服务器进行验证.
    func testHTTPBasicAuthenticationFailsWithInvalidCredentials() {
        // Given
        let session = Session()
        let endpoint = Endpoint.basicAuth()
        let expectation = expectation(description: "\(endpoint.url) 401")
        
        var response: DataResponse<Data?, AFError>?
        
        // When
        session.request(endpoint)
            .authenticate(username: "invalid", password: "credentials")
            .response { resp in
                response = resp
                expectation.fulfill()
            }
        
        // wait 这种, 在后续还要验证各种数据.
        waitForExpectations(timeout: timeout)
        
        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertEqual(response?.response?.statusCode, 401)
        XCTAssertNil(response?.data)
        XCTAssertNil(response?.error)
    }
    
    func testHTTPBasicAuthenticationWithValidCredentials() {
        // Given
        let session = Session()
        let user = "user1", password = "password"
        let endpoint = Endpoint.basicAuth(forUser: user, password: password)
        let expectation = expectation(description: "\(endpoint.url) 200")
        
        var response: DataResponse<Data?, AFError>?
        
        // When
        session.request(endpoint)
            .authenticate(username: user, password: password)
            .response { resp in
                response = resp
                expectation.fulfill()
            }
        
        waitForExpectations(timeout: timeout)
        
        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertEqual(response?.response?.statusCode, 200)
        XCTAssertNotNil(response?.data)
        XCTAssertNil(response?.error)
    }
    
    func testHTTPBasicAuthenticationWithStoredCredentials() {
        // Given 准备数据
        let session = Session()
        let user = "user2", password = "password"
        let endpoint = Endpoint.basicAuth(forUser: user, password: password)
        let expectation = expectation(description: "\(endpoint.url) 200")
        
        var response: DataResponse<Data?, AFError>?
        
        // When 执行
        let credential = URLCredential(user: user, password: password, persistence: .forSession)
        // 为特定的 URL, 添加一个 URLCredential, 在 Alamofire 里面, 会读取到这里. 
        URLCredentialStorage.shared.setDefaultCredential(credential,
                                                         for: .init(host: endpoint.host.rawValue,
                                                                    port: endpoint.port,
                                                                    protocol: endpoint.scheme.rawValue,
                                                                    realm: endpoint.host.rawValue,
                                                                    authenticationMethod: NSURLAuthenticationMethodHTTPBasic))
        session.request(endpoint)
            .response { resp in
                response = resp
                expectation.fulfill()
            }
        
        waitForExpectations(timeout: timeout)
        
        // Then 验证
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertEqual(response?.response?.statusCode, 200)
        XCTAssertNotNil(response?.data)
        XCTAssertNil(response?.error)
    }
    
    func testHiddenHTTPBasicAuthentication() {
        // Given
        let session = Session()
        let endpoint = Endpoint.hiddenBasicAuth()
        let expectation = expectation(description: "\(endpoint.url) 200")
        
        var response: DataResponse<Data?, AFError>?
        
        // When
        session.request(endpoint)
            .response { resp in
                response = resp
                expectation.fulfill()
            }
        
        waitForExpectations(timeout: timeout)
        
        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertEqual(response?.response?.statusCode, 200)
        XCTAssertNotNil(response?.data)
        XCTAssertNil(response?.error)
    }
}

// MARK: -

// Disabled due to HTTPBin flakiness.
final class HTTPDigestAuthenticationTestCase: BaseTestCase {
    func _testHTTPDigestAuthenticationWithInvalidCredentials() {
        // Given
        let session = Session()
        let endpoint = Endpoint.digestAuth()
        let expectation = expectation(description: "\(endpoint.url) 401")
        
        var response: DataResponse<Data?, AFError>?
        
        // When
        session.request(endpoint)
            .authenticate(username: "invalid", password: "credentials")
            .response { resp in
                response = resp
                expectation.fulfill()
            }
        
        waitForExpectations(timeout: timeout)
        
        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertEqual(response?.response?.statusCode, 401)
        XCTAssertNil(response?.data)
        XCTAssertNil(response?.error)
    }
    
    func _testHTTPDigestAuthenticationWithValidCredentials() {
        // Given
        let session = Session()
        let user = "user", password = "password"
        let endpoint = Endpoint.digestAuth(forUser: user, password: password)
        let expectation = expectation(description: "\(endpoint.url) 200")
        
        var response: DataResponse<Data?, AFError>?
        
        // When
        session.request(endpoint)
            .authenticate(username: user, password: password)
            .response { resp in
                response = resp
                expectation.fulfill()
            }
        
        waitForExpectations(timeout: timeout)
        
        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertEqual(response?.response?.statusCode, 200)
        XCTAssertNotNil(response?.data)
        XCTAssertNil(response?.error)
    }
}
