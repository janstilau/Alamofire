import Alamofire
import Foundation
import XCTest

class BaseTestCase: XCTestCase {
    let timeout: TimeInterval = 10
    
    var testDirectoryURL: URL {
        FileManager.temporaryDirectoryURL.appendingPathComponent("org.alamofire.tests")
    }
    
    var temporaryFileURL: URL {
        testDirectoryURL.appendingPathComponent(UUID().uuidString)
    }
    
    private var session: Session?
    
    override func setUp() {
        FileManager.createDirectory(at: testDirectoryURL)
        
        super.setUp()
    }
    
    override func tearDown() {
        session = nil
        FileManager.removeAllItemsInsideDirectory(at: testDirectoryURL)
        clearCredentials()
        clearCookies()
        
        super.tearDown()
    }
    
    func clearCookies(for storage: HTTPCookieStorage = .shared) {
        storage.cookies?.forEach { storage.deleteCookie($0) }
    }
    
    func clearCredentials(for storage: URLCredentialStorage = .shared) {
        for (protectionSpace, credentials) in storage.allCredentials {
            for (_, credential) in credentials {
                storage.remove(credential, for: protectionSpace)
            }
        }
    }
    
    func url(forResource fileName: String, withExtension ext: String) -> URL {
        Bundle.test.url(forResource: fileName, withExtension: ext)!
    }
    
    func stored(_ session: Session) -> Session {
        self.session = session
        
        return session
    }
    
    /// Runs assertions on a particular `DispatchQueue`.
    ///
    /// - Parameters:
    ///   - queue: The `DispatchQueue` on which to run the assertions.
    ///   - assertions: Closure containing assertions to run
    func assert(on queue: DispatchQueue, assertions: @escaping () -> Void) {
        let expect = expectation(description: "all assertions are complete")
        
        queue.async {
            assertions()
            expect.fulfill()
        }
        
        waitForExpectations(timeout: timeout)
    }
}
