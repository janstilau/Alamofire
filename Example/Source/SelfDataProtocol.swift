// Protocol implementation of data: URL scheme

import Foundation


// Iterate through a SubString validating that the input is ASCII and converting any %xx
// percent endcoded hex sequences to a UInt8 byte.
private struct _PercentDecoder: IteratorProtocol {
    
    enum Element {
        case asciiCharacter(Character)
        case decodedByte(UInt8)
        case invalid                    // Not ASCII or hex encoded
    }
    
    private let subString: Substring
    private var currentIndex: String.Index
    var remainingString: Substring { subString[currentIndex...] }
    
    
    init(subString: Substring) {
        self.subString = subString
        currentIndex = subString.startIndex
    }
    
    mutating private func nextChar() -> Character? {
        guard currentIndex < subString.endIndex else { return nil }
        let ch = subString[currentIndex]
        currentIndex = subString.index(after: currentIndex)
        return ch
    }
    
    mutating func next() -> _PercentDecoder.Element? {
        guard let ch = nextChar() else { return nil }
        
        guard let asciiValue = ch.asciiValue else { return .invalid }
        
        guard asciiValue == UInt8(ascii: "%") else {
            return .asciiCharacter(ch)
        }
        
        // Decode the %xx value
        guard let hiNibble = nextChar(), hiNibble.isASCII,
              let hiNibbleValue = hiNibble.hexDigitValue else {
            return .invalid
        }
        
        guard let loNibble = nextChar(), loNibble.isASCII,
              let loNibbleValue = loNibble.hexDigitValue else {
            return .invalid
        }
        let byte = UInt8(hiNibbleValue) << 4 | UInt8(loNibbleValue)
        return .decodedByte(byte)
    }
}


internal class _SelfURLProtocol: URLProtocol {
    
    fileprivate var errorReason: String = ""
    
    // canInit(with 里面, 就是根据 scheme 进行的判断.
    override class func canInit(with request: URLRequest) -> Bool {
        return request.url?.scheme == "self"
    }
    
    override class func canInit(with task: URLSessionTask) -> Bool {
        return task.currentRequest?.url?.scheme == "self"
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        guard let urlClient = self.client else { fatalError("No URLProtocol client set") }
        
        guard let userName = extractUsername(from: self.request), let pwd = extractPassword(from: self.request), userName == "lgq01", pwd == "lgq01Pwd" else {
            let challenge = URLAuthenticationChallenge(
                protectionSpace: URLProtectionSpace(
                    host: request.url?.host ?? "",
                    port: request.url?.port ?? 0,
                    protocol: request.url?.scheme,
                    realm: "Your Realm",
                    authenticationMethod: NSURLAuthenticationMethodHTTPBasic
                ),
                proposedCredential: nil,
                previousFailureCount: 0,
                failureResponse: nil,
                error: nil,
                sender: self
            )
            
            // Resolve the challenge by calling didReceive challenge
            client?.urlProtocol(self, didReceive: challenge)
            return
        }
        
        resume()
    }
    
    func resume() {
        guard let urlClient = self.client else { fatalError("No URLProtocol client set") }
        
        if let (response, decodedData) = decodeURI() {
            /*
             在 Protocol 的内部, 有着自己的一套规则可以判断, 是否应该缓存 Resposne 以及对应的 data.
             cacheStoragePolicy 到底如何填写, 由 Protocol 内部决定. 例如, HTTP Protocl, 就由 Method, Header 里面的缓存控制策略共同控制. 
             */
            urlClient.urlProtocol(self, didReceive: response, cacheStoragePolicy: .allowedInMemoryOnly)
            urlClient.urlProtocol(self, didLoad: decodedData)
            urlClient.urlProtocolDidFinishLoading(self)
        } else {
            let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorBadURL)
            urlClient.urlProtocol(self, didFailWithError: error)
        }
    }
    
    
    private func decodeURI() -> (URLResponse, Data)? {
        guard let url = self.request.url else {
            return nil
        }
        let dataBody = url.absoluteString
        guard dataBody.hasPrefix("self:") else {
            return nil
        }
        
        let startIdx = dataBody.index(dataBody.startIndex, offsetBy: 5)
        var iterator = _PercentDecoder(subString: dataBody[startIdx...])
        
        var mimeType: String?
        var charSet: String?
        var base64 = false
        
        // Simple validation that the mime type has only one '/' and its not at the start or end.
        func validate(mimeType: String) -> Bool {
            if mimeType.hasPrefix("/") { return false }
            var count = 0
            var lastChar: Character!
            
            for ch in mimeType {
                if ch == "/" { count += 1 }
                if count > 1 { return false }
                lastChar = ch
            }
            guard count == 1 else { return false }
            return lastChar != "/"
        }
        
        // Determine optional mime type, optional charset and whether ;base64 flag is just before a comma.
        func decodeHeader() -> Bool {
            let defaultMimeType = "text/plain"
            
            var part = ""
            var foundCharsetKey = false
            
            while let element = iterator.next() {
                switch element {
                case .asciiCharacter(let ch) where ch == Character(","):
                    // ";base64 must be the last part just before the ',' that seperates the header from the data
                    if foundCharsetKey {
                        charSet = part
                    } else {
                        base64 = (part == ";base64")
                    }
                    if mimeType == nil || !validate(mimeType: mimeType!) {
                        mimeType = defaultMimeType
                    }
                    return true
                    
                    
                case .asciiCharacter(let ch) where ch == Character(";"):
                    // First item is the mimeType if there is a '/' in the string
                    if mimeType == nil {
                        if part.contains("/") {
                            mimeType = part
                        } else {
                            mimeType = defaultMimeType // default value
                        }
                    }
                    if foundCharsetKey {
                        charSet = part
                        foundCharsetKey = false
                    }
                    part = ";"
                    
                case .asciiCharacter(let ch) where ch == Character("="):
                    if mimeType == nil {
                        mimeType = defaultMimeType
                    } else if part == ";charset" && charSet == nil {
                        foundCharsetKey = true
                        part = ""
                    }
                    
                case .asciiCharacter(let ch):
                    part += String(ch)
                    
                case .decodedByte(_), .invalid:
                    // Dont allow percent encoded bytes in the header.
                    return false
                }
            }
            // No comma found.
            return false
        }
        
        // Convert any percent encoding to bytes then pass the whole String to be Base64 decoded.
        // Let the Base64 decoder take care of input validation.
        func decodeBase64Body() -> Data? {
            var base64encoded = ""
            base64encoded.reserveCapacity(iterator.remainingString.count)
            
            while let element = iterator.next() {
                switch element {
                case .asciiCharacter(let ch):
                    base64encoded += String(ch)
                    
                case .decodedByte(let value) where UnicodeScalar(value).isASCII:
                    base64encoded += String(Character(UnicodeScalar(value)))
                    
                default: return nil
                }
            }
            base64encoded =             base64encoded.trimmingCharacters(in: .whitespacesAndNewlines)
            return Data(base64Encoded: base64encoded)
        }
        
        // Convert any percent encoding to bytes and append to a `Data` instance. The bytes may
        // be valid in the specified charset in the header and not necessarily UTF-8.
        func decodeStringBody() -> Data? {
            var data = Data()
            data.reserveCapacity(iterator.remainingString.count)
            
            while let ch = iterator.next() {
                switch ch {
                case .asciiCharacter(let ch): data.append(ch.asciiValue!)
                case .decodedByte(let value): data.append(value)
                default: return nil
                }
            }
            return data
        }
        
        guard decodeHeader() else { return nil }
        guard let decodedData = base64 ? decodeBase64Body() : decodeStringBody() else {
            return nil
        }
        
        let response = URLResponse(url: url, mimeType: mimeType, expectedContentLength: decodedData.count, textEncodingName: charSet)
        return (response, decodedData)
    }
    
    // Nothing to do here.
    override func stopLoading() {
        print("Stop Loading. Error: \(errorReason)")
    }
    
    private func extractUsername(from request: URLRequest) -> String? {
        // Implement logic to extract username from the request headers
        if let headers = request.allHTTPHeaderFields,
           let username = headers["Authorization"]?.split(separator: ":").first {
            // Assuming Basic Authentication is used and username is part of the Authorization header
            return String(username)
        }
        return nil
    }
    
    private func extractPassword(from request: URLRequest) -> String? {
        // Implement logic to extract password from the request headers
        if let headers = request.allHTTPHeaderFields,
           let base64Credentials = headers["Authorization"]?.split(separator: " ").last,
           let credentialsData = Data(base64Encoded: String(base64Credentials)),
           let password = String(data: credentialsData, encoding: .utf8)?.split(separator: ":").last {
            return String(password)
        }
        return nil
    }
}


extension _SelfURLProtocol: URLAuthenticationChallengeSender {
    func use(_ credential: URLCredential, for challenge: URLAuthenticationChallenge) {
        if credential.user == "lgq01", credential.password == "lgq01Pwd" {
            print("User Credential \(credential)")
            resume()
        }
    }
    
    func continueWithoutCredential(for challenge: URLAuthenticationChallenge) {
        errorReason = "Credential Empty"
        stopLoading()
    }
    
    func cancel(_ challenge: URLAuthenticationChallenge) {
        guard let urlClient = self.client else { fatalError("No URLProtocol client set") }
        urlClient.urlProtocol(self, didCancel: challenge)
        errorReason = "Credential Cancel"
        stopLoading()
    }
    
    func performDefaultHandling(for challenge: URLAuthenticationChallenge) {
        errorReason = "Credential performDefaultHandling"
        stopLoading()
    }
    
    func rejectProtectionSpaceAndContinue(with challenge: URLAuthenticationChallenge) {
        errorReason = "Credential rejectProtectionSpaceAndContinue"
        stopLoading()
    }
}
