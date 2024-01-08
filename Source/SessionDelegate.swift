import Foundation

/// Class which implements the various `URLSessionDelegate` methods to connect various Alamofire features.
// 在 AFN 里面, 真正的和 URLSession 打交道的, 被包装成为了一个 Delegate 类, 在 Alamofire 里面同样的思路.
open class SessionDelegate: NSObject {
    private let fileManager: FileManager

    // 这里面就是 Session.
    weak var stateProvider: SessionStateProvider?
    var eventMonitor: EventMonitor?

    /// Creates an instance from the given `FileManager`.
    ///
    /// - Parameter fileManager: `FileManager` to use for underlying file management, such as moving downloaded files.
    ///                          `.default` by default.
    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// Internal method to find and cast requests while maintaining some integrity checking.
    ///
    /// - Parameters:
    ///   - task: The `URLSessionTask` for which to find the associated `Request`.
    ///   - type: The `Request` subclass type to cast any `Request` associate with `task`.
    func request<R: Request>(for task: URLSessionTask, as type: R.Type) -> R? {
        guard let provider = stateProvider else {
            assertionFailure("StateProvider is nil.")
            return nil
        }

        return provider.request(for: task) as? R
    }
}

/// Type which provides various `Session` state values.
// 这里面的, 都是 URLSession Delegate 所需要的.
// 将所需要的方法, 类型抽象出来, 然后交给 Session 来进行实现. 
protocol SessionStateProvider: AnyObject {
    var serverTrustManager: ServerTrustManager? { get }
    var redirectHandler: RedirectHandler? { get }
    var cachedResponseHandler: CachedResponseHandler? { get }

    func request(for task: URLSessionTask) -> Request?
    func didGatherMetricsForTask(_ task: URLSessionTask)
    func didCompleteTask(_ task: URLSessionTask, completion: @escaping () -> Void)
    func credential(for task: URLSessionTask, in protectionSpace: URLProtectionSpace) -> URLCredential?
    func cancelRequestsForSessionInvalidation(with error: Error?)
}

// MARK: URLSessionDelegate
// 以下则是在 URLSession 的各个事件里面, 触发对应的方法.

// Session 不存在了之后, Alamofire 里面, 也要通知自己的 Request 相关的信息. 
extension SessionDelegate: URLSessionDelegate {
    open func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        eventMonitor?.urlSession(session, didBecomeInvalidWithError: error)
        stateProvider?.cancelRequestsForSessionInvalidation(with: error)
    }
}

// MARK: URLSessionTaskDelegate

extension SessionDelegate: URLSessionTaskDelegate {
    /// Result of a `URLAuthenticationChallenge` evaluation.
    // 如果处理, 凭证, 错误.
    typealias ChallengeEvaluation = (disposition: URLSession.AuthChallengeDisposition, credential: URLCredential?, error: AFError?)

    open func urlSession(_ session: URLSession,
                         task: URLSessionTask,
                         didReceive challenge: URLAuthenticationChallenge,
                         completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        eventMonitor?.urlSession(session, task: task, didReceive: challenge)

        let evaluation: ChallengeEvaluation
        switch challenge.protectionSpace.authenticationMethod {
        case NSURLAuthenticationMethodHTTPBasic,
            NSURLAuthenticationMethodHTTPDigest,
            NSURLAuthenticationMethodNTLM,
             NSURLAuthenticationMethodNegotiate:
            /*
             NSURLAuthenticationMethodHTTPBasic:
             代表：基本认证（Basic Authentication）。
             例子：一个客户端向服务器发送请求，服务器响应一个需要认证的状态码（如 401 Unauthorized）。客户端随后发送带有 Authorization: Basic [Base64编码的用户名:密码] 头部的请求。
             NSURLAuthenticationMethodHTTPDigest:
             代表：摘要认证（Digest Authentication）。
             例子：客户端请求资源，服务器返回一个挑战（challenge），包含一个特定域（realm）和一个随机数（nonce）。客户端使用用户名、密码、随机数、请求方法和请求的 URI 生成响应（response），并将这个响应发送回服务器以验证。
             NSURLAuthenticationMethodNTLM:
             代表：NT LAN Manager（NTLM）认证，主要用于Windows网络。
             例子：客户端发送请求，服务器响应要求 NTLM 认证。客户端发送一个包含 NTLM 消息的请求，服务器验证这个消息并返回认证状态。
             NSURLAuthenticationMethodNegotiate:
             代表：协商认证，一种集成的认证框架（通常是 Kerberos 或者 NTLM）。
             例子：客户端发送请求，服务器返回一个协商认证的挑战。客户端使用支持的认证机制（如 Kerberos）响应挑战，服务器验证并授予访问权限
             */
            evaluation = attemptCredentialAuthentication(for: challenge, belongingTo: task)
        #if canImport(Security)
        case NSURLAuthenticationMethodServerTrust:
            evaluation = attemptServerTrustAuthentication(with: challenge)
        case NSURLAuthenticationMethodClientCertificate:
            // 不管.
            evaluation = attemptCredentialAuthentication(for: challenge, belongingTo: task)
        #endif
        default:
            evaluation = (.performDefaultHandling, nil, nil)
        }

        if let error = evaluation.error {
            stateProvider?.request(for: task)?.didFailTask(task, earlyWithError: error)
        }

        completionHandler(evaluation.disposition, evaluation.credential)
    }

    #if canImport(Security)
    /// Evaluates the server trust `URLAuthenticationChallenge` received.
    ///
    /// - Parameter challenge: The `URLAuthenticationChallenge`.
    ///
    /// - Returns:             The `ChallengeEvaluation`.
    func attemptServerTrustAuthentication(with challenge: URLAuthenticationChallenge) -> ChallengeEvaluation {
        
        let host = challenge.protectionSpace.host
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust
        else {
            return (.performDefaultHandling, nil, nil)
        }

        // challenge.protectionSpace.serverTrust 这里面, 装的就是服务端发过来的证书了.
        // 将服务器证书验证的逻辑, 都封装到了 evaluator 这个类里面了.
        do {
            guard let evaluator = try stateProvider?.serverTrustManager?.serverTrustEvaluator(forHost: host) else {
                return (.performDefaultHandling, nil, nil)
            }

            try evaluator.evaluate(trust, forHost: host)

            return (.useCredential, URLCredential(trust: trust), nil)
        } catch {
            return (.cancelAuthenticationChallenge, nil, error.asAFError(or: .serverTrustEvaluationFailed(reason: .customEvaluationFailed(error: error))))
        }
    }
    #endif

    /// Evaluates the credential-based authentication `URLAuthenticationChallenge` received for `task`.
    ///
    /// - Parameters:
    ///   - challenge: The `URLAuthenticationChallenge`.
    ///   - task:      The `URLSessionTask` which received the challenge.
    ///
    /// - Returns:     The `ChallengeEvaluation`.
    // 对于 401 里面的那种认证, 或者是客户端认证, 会到这里来.
    func attemptCredentialAuthentication(for challenge: URLAuthenticationChallenge,
                                         belongingTo task: URLSessionTask) -> ChallengeEvaluation {
        guard challenge.previousFailureCount == 0 else {
            return (.rejectProtectionSpace, nil, nil)
        }

        guard let credential = stateProvider?.credential(for: task, in: challenge.protectionSpace) else {
            return (.performDefaultHandling, nil, nil)
        }

        return (.useCredential, credential, nil)
    }
    
    
    
    // 发送过程, 不断地触发这里.
    open func urlSession(_ session: URLSession,
                         task: URLSessionTask,
                         didSendBodyData bytesSent: Int64,
                         totalBytesSent: Int64,
                         totalBytesExpectedToSend: Int64) {
        // 使用 eventMonitor 通知外界.
        eventMonitor?.urlSession(session,
                                 task: task,
                                 didSendBodyData: bytesSent,
                                 totalBytesSent: totalBytesSent,
                                 totalBytesExpectedToSend: totalBytesExpectedToSend)
        // 更新 Request 对象里面的数据.
        stateProvider?.request(for: task)?.updateUploadProgress(totalBytesSent: totalBytesSent,
                                                                totalBytesExpectedToSend: totalBytesExpectedToSend)
    }

    open func urlSession(_ session: URLSession,
                         task: URLSessionTask,
                         needNewBodyStream completionHandler: @escaping (InputStream?) -> Void) {
        eventMonitor?.urlSession(session, taskNeedsNewBodyStream: task)

        guard let request = request(for: task, as: UploadRequest.self) else {
            assertionFailure("needNewBodyStream did not find UploadRequest.")
            completionHandler(nil)
            return
        }

        completionHandler(request.inputStream())
    }

    // 重定向的 delegate.
    open func urlSession(_ session: URLSession,
                         task: URLSessionTask,
                         willPerformHTTPRedirection response: HTTPURLResponse,
                         newRequest request: URLRequest,
                         completionHandler: @escaping (URLRequest?) -> Void) {
        eventMonitor?.urlSession(session, task: task, willPerformHTTPRedirection: response, newRequest: request)

        if let redirectHandler = stateProvider?.request(for: task)?.redirectHandler ?? stateProvider?.redirectHandler {
            redirectHandler.task(task, willBeRedirectedTo: request, for: response, completion: completionHandler)
        } else {
            completionHandler(request)
        }
    }

    // 这个在 Foundation 库里面没有实现.
    open func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        eventMonitor?.urlSession(session, task: task, didFinishCollecting: metrics)

        stateProvider?.request(for: task)?.didGatherMetrics(metrics)

        stateProvider?.didGatherMetricsForTask(task)
    }

    /*
     func urlProtocolDidFinishLoading(_ urlProtocol: URLProtocol)
     func urlProtocol(task: URLSessionTask, didFailWithError error: Error)
     在这两个方法里面, 会触发到这里.  也算是终点 到 终点.
     */
    open func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        eventMonitor?.urlSession(session, task: task, didCompleteWithError: error)

        let request = stateProvider?.request(for: task)

        stateProvider?.didCompleteTask(task) {
            request?.didCompleteTask(task, with: error.map { $0.asAFError(or: .sessionTaskFailed(error: $0)) })
        }
    }

    @available(macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *)
    open func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
        eventMonitor?.urlSession(session, taskIsWaitingForConnectivity: task)
    }
}

// MARK: URLSessionDataDelegate

extension SessionDelegate: URLSessionDataDelegate {
    // 当收到了 URLResponse 的时候会被调用.
    open func urlSession(_ session: URLSession,
                         dataTask: URLSessionDataTask,
                         didReceive response: URLResponse,
                         completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        eventMonitor?.urlSession(session, dataTask: dataTask, didReceive: response)

        guard let response = response as? HTTPURLResponse else { completionHandler(.allow); return }

        if let request = request(for: dataTask, as: DataRequest.self) {
            request.didReceiveResponse(response, completionHandler: completionHandler)
        } else if let request = request(for: dataTask, as: DataStreamRequest.self) {
            request.didReceiveResponse(response, completionHandler: completionHandler)
        } else {
            assertionFailure("dataTask did not find DataRequest or DataStreamRequest in didReceive response")
            completionHandler(.allow)
            return
        }
    }

    open func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        eventMonitor?.urlSession(session, dataTask: dataTask, didReceive: data)

        if let request = request(for: dataTask, as: DataRequest.self) {
            request.didReceive(data: data)
        } else if let request = request(for: dataTask, as: DataStreamRequest.self) {
            request.didReceive(data: data)
        } else {
            assertionFailure("dataTask did not find DataRequest or DataStreamRequest in didReceive data")
            return
        }
    }

    // URL Cache 进行 reponse 和 data 存储的过程. 
    open func urlSession(_ session: URLSession,
                         dataTask: URLSessionDataTask,
                         willCacheResponse proposedResponse: CachedURLResponse,
                         completionHandler: @escaping (CachedURLResponse?) -> Void) {
        eventMonitor?.urlSession(session, dataTask: dataTask, willCacheResponse: proposedResponse)

        // 这个 completionHandler 其实是在 URLSession 里面设计的.
        // 如果传递一个 Nil 过去. 那边就不进行存储了. 
        if let handler = stateProvider?.request(for: dataTask)?.cachedResponseHandler ?? stateProvider?.cachedResponseHandler {
            handler.dataTask(dataTask, willCacheResponse: proposedResponse, completion: completionHandler)
        } else {
            completionHandler(proposedResponse)
        }
    }
}

// MARK: URLSessionDownloadDelegate

extension SessionDelegate: URLSessionDownloadDelegate {
    open func urlSession(_ session: URLSession,
                         downloadTask: URLSessionDownloadTask,
                         didResumeAtOffset fileOffset: Int64,
                         expectedTotalBytes: Int64) {
        eventMonitor?.urlSession(session,
                                 downloadTask: downloadTask,
                                 didResumeAtOffset: fileOffset,
                                 expectedTotalBytes: expectedTotalBytes)
        guard let downloadRequest = request(for: downloadTask, as: DownloadRequest.self) else {
            assertionFailure("downloadTask did not find DownloadRequest.")
            return
        }

        downloadRequest.updateDownloadProgress(bytesWritten: fileOffset,
                                               totalBytesExpectedToWrite: expectedTotalBytes)
    }

    open func urlSession(_ session: URLSession,
                         downloadTask: URLSessionDownloadTask,
                         didWriteData bytesWritten: Int64,
                         totalBytesWritten: Int64,
                         totalBytesExpectedToWrite: Int64) {
        eventMonitor?.urlSession(session,
                                 downloadTask: downloadTask,
                                 didWriteData: bytesWritten,
                                 totalBytesWritten: totalBytesWritten,
                                 totalBytesExpectedToWrite: totalBytesExpectedToWrite)
        guard let downloadRequest = request(for: downloadTask, as: DownloadRequest.self) else {
            assertionFailure("downloadTask did not find DownloadRequest.")
            return
        }

        downloadRequest.updateDownloadProgress(bytesWritten: bytesWritten,
                                               totalBytesExpectedToWrite: totalBytesExpectedToWrite)
    }

    // 这里就是下载完毕了.
    open func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        eventMonitor?.urlSession(session, downloadTask: downloadTask, didFinishDownloadingTo: location)

        guard let request = request(for: downloadTask, as: DownloadRequest.self) else {
            assertionFailure("downloadTask did not find DownloadRequest.")
            return
        }

        let (destination, options): (URL, DownloadRequest.Options)
        if let response = request.response {
            (destination, options) = request.destination(location, response)
        } else {
            // If there's no response this is likely a local file download, so generate the temporary URL directly.
            (destination, options) = (DownloadRequest.defaultDestinationURL(location), [])
        }

        eventMonitor?.request(request, didCreateDestinationURL: destination)

        do {
            if options.contains(.removePreviousFile), fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }

            if options.contains(.createIntermediateDirectories) {
                let directory = destination.deletingLastPathComponent()
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            }
            
            // 经典的移动文件的环节. 
            try fileManager.moveItem(at: location, to: destination)

            request.didFinishDownloading(using: downloadTask, with: .success(destination))
        } catch {
            request.didFinishDownloading(using: downloadTask, with: .failure(.downloadedFileMoveFailed(error: error,
                                                                                                       source: location,
                                                                                                       destination: destination)))
        }
    }
}
