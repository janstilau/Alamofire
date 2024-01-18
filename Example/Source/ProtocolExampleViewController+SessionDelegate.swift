//
//  ProtocolExampleViewController+SessionDelegate.swift
//  iOS Example
//
//  Created by liuguoqiang on 2024/1/16.
//  Copyright © 2024 Alamofire. All rights reserved.
//

import Foundation


extension ProtocolExampleViewController: URLSessionDelegate, URLSessionDataDelegate, URLSessionTaskDelegate {
    
    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        print("didReceive response: \(response)")
        completionHandler(.allow)
//        completionHandler(.becomeDownload)
        // 使用 becomeDownload, 必须实现下面的方法.
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome downloadTask: URLSessionDownloadTask) {
        print("didBecome downloadTask \(downloadTask)")
    }
    
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        if let error {
            print("didCompleteWithError :\(error), protocol :\(protocolName)")
        } else {
            if protocolName == "file" {
                if let fileContent = String.init(data: mutableData, encoding: .utf8) {
                    print("File Content: \(fileContent)")
                }
            } else if ["data", "self"].contains(protocolName) {
                if let dataContent = try? JSONSerialization.jsonObject(with: mutableData) {
                    print("Data Content: \(dataContent)")
                }
            } else if protocolName == "selffile" {
                if let fileContent = String.init(data: mutableData, encoding: .utf8) {
                    print("File Content: \(fileContent)")
                }
            }
        }
        
    }
    
    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive data: Data) {
        print("didReceive Data \(data.count)")
        mutableData.append(data)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse, completionHandler: @escaping (CachedURLResponse?) -> Void) {
        print("willCacheResponse \(proposedResponse)")
        completionHandler(proposedResponse)
    }
    
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        print("didReceive challenge. session: \(session), task: \(task), challenge: \(challenge)")
        let userNamePasswork = URLCredential(user: "lgq01", password: "lgq01Pwd", persistence: .permanent)
        completionHandler(.useCredential, userNamePasswork)
    }
}

extension ProtocolExampleViewController: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        print("Downloaded URL \(location)")
        do {
              let data = try Data(contentsOf: location)
              if let stringData = String(data: data, encoding: .utf8) {
                  print("Downloaded data as String: \(stringData)")
              } else {
                  print("Failed to convert data to String.")
              }
          } catch {
              print("Error reading downloaded data: \(error)")
          }
    }

    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        print("Download didWriteData \(bytesWritten) totalBytesWritten \(totalBytesWritten) totalBytesExpectedToWrite\(totalBytesExpectedToWrite)")
    }
}
