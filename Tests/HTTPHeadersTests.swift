import Alamofire
import XCTest

class HTTPHeadersTests: BaseTestCase {
    // 这里的 Key 有大写, 有小写, 但是在内部里面, 都是进行的小写处理的.
    func testHeadersAreStoreUniquelyByCaseInsensitiveName() {
        // Given
        let headersFromDictionaryLiteral: HTTPHeaders = ["key": "", "Key": "", "KEY": ""]
        let headersFromDictionary = HTTPHeaders(["key": "", "Key": "", "KEY": ""])
        let headersFromArrayLiteral: HTTPHeaders = [HTTPHeader(name: "key", value: ""),
                                                    HTTPHeader(name: "Key", value: ""),
                                                    HTTPHeader(name: "KEY", value: "")]
        let headersFromArray = HTTPHeaders([HTTPHeader(name: "key", value: ""),
                                            HTTPHeader(name: "Key", value: ""),
                                            HTTPHeader(name: "KEY", value: "")])
        var headersCreatedManually = HTTPHeaders()
        headersCreatedManually.update(HTTPHeader(name: "key", value: ""))
        headersCreatedManually.update(name: "Key", value: "")
        headersCreatedManually.update(name: "KEY", value: "")
        
        // When, Then
        XCTAssertEqual(headersFromDictionaryLiteral.count, 1)
        XCTAssertEqual(headersFromDictionary.count, 1)
        XCTAssertEqual(headersFromArrayLiteral.count, 1)
        XCTAssertEqual(headersFromArray.count, 1)
        XCTAssertEqual(headersCreatedManually.count, 1)
    }
    
    // 测试, 会按照插入的顺序, 进行排列.
    func testHeadersPreserveOrderOfInsertion() {
        // Given
        let headersFromDictionaryLiteral: HTTPHeaders = ["c": "", "a": "", "b": ""]
        // Dictionary initializer can't preserve order.
        let headersFromArrayLiteral: HTTPHeaders = [HTTPHeader(name: "b", value: ""),
                                                    HTTPHeader(name: "a", value: ""),
                                                    HTTPHeader(name: "c", value: "")]
        let headersFromArray = HTTPHeaders([HTTPHeader(name: "b", value: ""),
                                            HTTPHeader(name: "a", value: ""),
                                            HTTPHeader(name: "c", value: "")])
        var headersCreatedManually = HTTPHeaders()
        headersCreatedManually.update(HTTPHeader(name: "c", value: ""))
        headersCreatedManually.update(name: "b", value: "")
        headersCreatedManually.update(name: "a", value: "")
        
        // When
        let dictionaryLiteralNames = headersFromDictionaryLiteral.map(\.name)
        let arrayLiteralNames = headersFromArrayLiteral.map(\.name)
        let arrayNames = headersFromArray.map(\.name)
        let manualNames = headersCreatedManually.map(\.name)
        
        // Then
        XCTAssertEqual(dictionaryLiteralNames, ["c", "a", "b"])
        XCTAssertEqual(arrayLiteralNames, ["b", "a", "c"])
        XCTAssertEqual(arrayNames, ["b", "a", "c"])
        XCTAssertEqual(manualNames, ["c", "b", "a"])
    }
    
    func testHeadersCanBeProperlySortedByName() {
        // Given
        let headers: HTTPHeaders = ["c": "", "a": "", "b": ""]
        
        // When
        let sortedHeaders = headers.sorted()
        
        // Then
        XCTAssertEqual(headers.map(\.name), ["c", "a", "b"])
        XCTAssertEqual(sortedHeaders.map(\.name), ["a", "b", "c"])
    }
    
    // 测试可以根据下标进行修改, 大小写不敏感. 
    func testHeadersCanInsensitivelyGetAndSetThroughSubscript() {
        // Given
        var headers: HTTPHeaders = ["c": "", "a": "", "b": ""]
        
        // When
        headers["C"] = "c"
        headers["a"] = "a"
        headers["b"] = "b"
        
        // Then
        XCTAssertEqual(headers["c"], "c")
        XCTAssertEqual(headers.map(\.value), ["c", "a", "b"])
        XCTAssertEqual(headers.count, 3)
    }
    
    func testHeadersPreserveLastFormAndValueOfAName() {
        // Given
        var headers: HTTPHeaders = ["c": "a"]
        
        // When
        headers["C"] = "c"
        
        // Then
        XCTAssertEqual(headers.description, "C: c")
    }
    
    func testHeadersHaveUnsortedDescription() {
        // Given
        let headers: HTTPHeaders = ["c": "c", "a": "a", "b": "b"]
        
        // When
        let description = headers.description
        let expectedDescription = """
        c: c
        a: a
        b: b
        """
        
        // Then
        XCTAssertEqual(description, expectedDescription)
    }
}
