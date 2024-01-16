//
//  ProtocolExampleViewController.swift
//  iOS Example
//
//  Created by liuguoqiang on 2024/1/10.
//  Copyright © 2024 Alamofire. All rights reserved.
//

import UIKit

class ProtocolExampleViewController: UIViewController {
    
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    
    lazy var session: URLSession = {
        var config = URLSessionConfiguration.default
        config.protocolClasses = [_SelfDataURLProtocol.self, _SelfFileURLProtocol.self]
        let session = URLSession(configuration: config, delegate: self, delegateQueue: .main)
        return session
    }()
    lazy var mutableData = Data()
    fileprivate var protocolName: String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupScrollView()
        setupStackView()
        setupViews()
        URLProtocol.registerClass(_SelfDataURLProtocol.self)
        URLProtocol.registerClass(_SelfFileURLProtocol.self)
    }
    
    private func setupViews() {
        addButton(title: "DataProtocol") {
            self.jsonDataProtocol()
        }
        addButton(title: "DataProtocolDelegate") {
            self.jsonDataProtocolDelegate()
        }
        addButton(title: "FileProtocol") {
            self.fileProtocol()
        }
        addButton(title: "FileProtocolDelegate") {
            self.fileProtocolDelegate()
        }
        addButton(title: "SelfDataProtocol") {
            self.selfDataProtocol()
        }
        addButton(title: "SelfDataProtocolDelegate") {
            self.selfDataProtocolDelegate()
        }
        addButton(title: "SelfFileProtocol") {
            self.selfFileProtocol()
        }
        addButton(title: "SelfFileProtocolDelegate") {
            self.selfFileProtocolDelegate()
        }
    }
    
    private func setupScrollView() {
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
    
    private func setupStackView() {
        scrollView.addSubview(stackView)
        stackView.axis = .vertical
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }
    
    func addButton(title: String, action: @escaping () -> Void) {
        let button = UIButton()
        button.setTitle(title, for: .normal)
        button.backgroundColor = .random
        button.setTitleColor(.black, for: .normal)
        button.heightAnchor.constraint(equalToConstant: 150).isActive = true
        button.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
        stackView.addArrangedSubview(button)
        // 保存按钮的动作
        buttonActions[button] = action
    }
    
    private var buttonActions = [UIButton: () -> Void]()
    
    @objc private func buttonTapped(_ sender: UIButton) {
        buttonActions[sender]?()
    }
}


extension ProtocolExampleViewController {
    func jsonDataProtocol() {
        guard let fileURL = Bundle.main.url(forResource: "JSONExample", withExtension: "txt"),
              let fileContents = try? String(contentsOf: fileURL).trimmingCharacters(in: .whitespacesAndNewlines) else {
            print("File not found or cannot be read")
            return
        }
        
        guard let dataURL = URL(string: "\(fileContents)") else {
            print("Invalid data URL")
            return
        }
        
        let task = URLSession.shared.dataTask(with: dataURL) { data, response, error in
            if let error = error {
                print("Error fetching data: \(error)")
                return
            }
            
            if let data = data {
                do {
                    // 解析 JSON 数据
                    if let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        // 成功解析 JSON
                        print("JSON fetched: \(jsonObject)")
                    } else {
                        print("Invalid JSON format")
                    }
                } catch {
                    print("JSON parsing error: \(error)")
                }
            }
            
        }
        task.resume()
    }
    
    func jsonDataProtocolDelegate() {
        guard let fileURL = Bundle.main.url(forResource: "JSONExample", withExtension: "txt"),
              let fileContents = try? String(contentsOf: fileURL).trimmingCharacters(in: .whitespacesAndNewlines) else {
            print("File not found or cannot be read")
            return
        }
        
        guard let dataURL = URL(string: "\(fileContents)") else {
            print("Invalid data URL")
            return
        }
        let request = URLRequest.init(url: dataURL)
        let task = self.session.dataTask(with: request)
        mutableData.removeAll()
        protocolName = "file"
        task.resume()
    }
}


extension ProtocolExampleViewController {
    func fileProtocol() {
        // 获取 Documents 目录路径
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDirectory.appendingPathComponent("ExampleFile.txt")
        
        // 创建 URLSession 数据任务来读取文件内容
        let task = self.session.dataTask(with: fileURL) { data, response, error in
            if let error = error {
                print("Error fetching file: \(error)")
                return
            }
            
            if let data = data, let fileContent = String(data: data, encoding: .utf8) {
                // 处理文件内容
                print("File content: \(fileContent)")
            }
        }
        task.resume()
    }
    
    func fileProtocolDelegate() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDirectory.appendingPathComponent("ExampleFile.txt")
        let request = URLRequest.init(url: fileURL)
        let task = self.session.dataTask(with: request)
        mutableData.removeAll()
        protocolName = "data"
        task.resume()
    }
}

extension ProtocolExampleViewController {
    func selfDataProtocol() {
        guard let fileURL = Bundle.main.url(forResource: "SelfJSONExample", withExtension: "txt"),
              let fileContents = try? String(contentsOf: fileURL).trimmingCharacters(in: .whitespacesAndNewlines) else {
            print("File not found or cannot be read")
            return
        }
        
        guard let dataURL = URL(string: "\(fileContents)") else {
            print("Invalid data URL")
            return
        }
        
        let task = URLSession.shared.dataTask(with: dataURL) { data, response, error in
            if let error = error {
                print("Error fetching data: \(error)")
                return
            }
            
            if let data = data {
                do {
                    // 解析 JSON 数据
                    if let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        // 成功解析 JSON
                        print("JSON fetched: \(jsonObject)")
                    } else {
                        print("Invalid JSON format")
                    }
                } catch {
                    print("JSON parsing error: \(error)")
                }
            }
            
        }
        task.resume()
    }
    
    func selfDataProtocolDelegate() {
        guard let fileURL = Bundle.main.url(forResource: "SelfJSONExample", withExtension: "txt"),
              let fileContents = try? String(contentsOf: fileURL).trimmingCharacters(in: .whitespacesAndNewlines) else {
            print("File not found or cannot be read")
            return
        }
        
        guard let dataURL = URL(string: "\(fileContents)") else {
            print("Invalid data URL")
            return
        }
        let request = URLRequest.init(url: dataURL)
        let task = self.session.dataTask(with: request)
        mutableData.removeAll()
        protocolName = "self"
        task.resume()
    }
}

extension ProtocolExampleViewController {
    func selfFileProtocol() {
        guard let selfFileUrl = URL(string: "selffile://localbundle.com/docs/index.html") else {
            print("Invalid data URL")
            return
        }
        
        let task = URLSession.shared.dataTask(with: selfFileUrl) { data, response, error in
            if let error = error {
                print("Error fetching data: \(error)")
                return
            }
            
            if let data = data {
                do {
                    if let htmlStr = String.init(data: data, encoding: .utf8) {
                        // 成功解析 JSON
                        print("Html fetched: \(htmlStr)")
                    } else {
                        print("Invalid String")
                    }
                } catch {
                    print("Html parsing error: \(error)")
                }
            }
            
        }
        task.resume()
    }
    
    func selfFileProtocolDelegate() {
        guard let selfFileUrl = URL(string: "selffile://localbundle.com/docs/index.html") else {
            print("Invalid data URL")
            return
        }
        
        let request = URLRequest.init(url: selfFileUrl)
        let task = self.session.dataTask(with: request)
        mutableData.removeAll()
        protocolName = "selffile"
        task.resume()
    }
}

extension ProtocolExampleViewController: URLSessionDelegate, URLSessionDataDelegate, URLSessionTaskDelegate {
    
    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        print("didReceive response: \(response)")
        completionHandler(.allow)
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
