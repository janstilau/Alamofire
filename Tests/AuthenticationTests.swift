import Alamofire
import Foundation
import XCTest

final class BasicAuthenticationTestCase: BaseTestCase {
    
    /*
     http://127.0.0.1:8080/basic-auth/user/password, NSErrorFailingURLKey=http://127.0.0.1:8080/basic-auth/user/password
     */
    // 对于这种测试用例, 需要起一个本地的服务器进行验证.
    /*
     Given 设置条件
     When 进行操作
     Then 查看结果
     
     Given（假设）：这一部分描述测试开始之前的初始状态或者前提条件。这是设置测试场景的地方，确保系统处于一个已知的状态，以便后续的操作和断言。在这里，你会设置对象、初始化变量，或者进行其他必要的准备工作。
     When（当）：这一部分描述你要测试的行为或者操作。这是触发被测代码的地方，即你想要测试的那个方法或者功能。在这里，你会调用某个方法、执行某个操作，引发系统状态的改变。
     Then（那么）：这一部分描述你期望的结果或者行为。在这里，你会检查系统的状态，验证调用后的效果是否符合预期。这可能涉及到断言，以确保系统在给定的条件下产生了正确的输出。
     */
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
        // 如果发送的是一个不符合的请求, 应该是 401, 但是不算是发生了错误.
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
        // 发送了正确的, 就应该数据部分返回了.
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertEqual(response?.response?.statusCode, 200)
        XCTAssertNotNil(response?.data)
        XCTAssertNil(response?.error)
    }
    // 以上, 是数据放到 URL 中进行发送的形式.
    
    func testHTTPBasicAuthenticationWithStoredCredentials() {
        // Given 准备数据
        let session = Session()
        let user = "user2", password = "password"
        let endpoint = Endpoint.basicAuth(forUser: user, password: password)
        let expectation = expectation(description: "\(endpoint.url) 200")
        
        var response: DataResponse<Data?, AFError>?
        
        // When 执行
        let credential = URLCredential(user: user, password: password, persistence: .forSession)
        // 设置默认的证书, 会在 performDefaultHandle 的时候, 去 defaultCredential 中查找证书的.
        // 所以, 就算没有专门提供证书, 也可以正常的进行发送.
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
        // 明确的, 通过了 authenticate 方法, 添加了对应的证书信息. 
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
