import Foundation

class _SelfFileURLProtocol: URLProtocol {

    var fileData: Data?
    var offset: Int = 0
    var chunkSize: Int = 1024  // 每次发送的数据块大小
    var delayTime: TimeInterval = 0.1  // 每次发送后的延时时间
    var timer: Timer?

    override class func canInit(with request: URLRequest) -> Bool {
        return request.url?.scheme == "selffile"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let url = request.url else { return }
        var filepath = url.path
        if filepath.hasPrefix("/") {
            let start = filepath.index(after: filepath.startIndex)
            filepath = String(filepath[start..<filepath.endIndex])
        }
        if let path = Bundle.main.path(forResource: url.path, ofType: nil),
           let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
            fileData = data
            sendResponse()
        } else {
            // 如果找不到文件，触发 error
            let error = NSError(domain: "com.example.SelfFileURLProtocol", code: 404, userInfo: nil)
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    // 清理工作, 在发送完成, 失败, 取消的时候, 会由上层主动地进行调用.
    override func stopLoading() {
        // 可以在这里进行一些清理工作
        timer?.invalidate()
    }

    private func sendResponse() {
        let response = URLResponse(url: request.url!, mimeType: nil, expectedContentLength: fileData?.count ?? 0, textEncodingName: nil)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)

        // 启动 Timer，定时发送数据块
        timer = Timer.scheduledTimer(timeInterval: delayTime, target: self, selector: #selector(sendNextChunk), userInfo: nil, repeats: true)
    }

    @objc private func sendNextChunk() {
        guard let fileData = fileData else {
            timer?.invalidate()
            return
        }

        let remainingLength = fileData.count - offset
        let chunkRange = offset..<(offset + min(chunkSize, remainingLength))
        let chunkData = fileData.subdata(in: chunkRange)

        client?.urlProtocol(self, didLoad: chunkData)
        
        offset += chunkSize

        // 如果还有剩余数据，继续发送下一块；否则，停止加载
        if offset >= fileData.count {
            client?.urlProtocolDidFinishLoading(self)
            timer?.invalidate()
        }
    }
}
