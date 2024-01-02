@testable import Alamofire
import XCTest

final class InternalRequestTests: BaseTestCase {
    func testThatMultipleFinishInvocationsDoNotCallSerializersMoreThanOnce() {
        // Given
        let session = Session(rootQueue: .main, startRequestsImmediately: false)
        let expect = expectation(description: "request complete")
        var response: DataResponse<Data?, AFError>?

        // When
        let request = session.request(.get).response { resp in
            response = resp
            expect.fulfill()
        }

        for _ in 0..<100 {
            request.finish()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(response)
    }

    #if canImport(zlib)
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testThatRequestCompressorProperlyCalculatesAdler32() {
        // Given
        let compressor = DeflateRequestCompressor()

        // When
        let checksum = compressor.adler32Checksum(of: Data("Wikipedia".utf8))

        // Then
        // From https://en.wikipedia.org/wiki/Adler-32
        XCTAssertEqual(checksum, 300_286_872)
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testThatRequestCompressorDeflatesDataCorrectly() throws {
        // Given
        let compressor = DeflateRequestCompressor()

        // When
        let compressedData = try compressor.deflate(Data([0]))

        // Then
        XCTAssertEqual(compressedData, Data([0x78, 0x5E, 0x63, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01]))
    }
    #endif
}
