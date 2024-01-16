//
//  WebViewController.swift
//  iOS Example
//
//  Created by liuguoqiang on 2024/1/16.
//  Copyright © 2024 Alamofire. All rights reserved.
//

import UIKit
import WebKit

class WebViewController: UIViewController {

    var webView: WKWebView!

    override func viewDidLoad() {
        super.viewDidLoad()

        // 创建 WKWebView 实例
        webView = WKWebView()
        webView.navigationDelegate = self // 设置导航代理，可选

        // 将 WKWebView 添加到视图中
        view.addSubview(webView)

        // 设置 WKWebView 的约束，如果使用 Auto Layout
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // 加载 Bundle 内的 HTML 文件
        if let htmlPath = Bundle.main.path(forResource: "docs/index", ofType: "html"),
           let htmlString = try? String(contentsOfFile: htmlPath) {
            webView.loadHTMLString(htmlString, baseURL: Bundle.main.bundleURL)
        }
    }
}

// 如果需要处理 WKWebView 的导航事件，可以实现 WKNavigationDelegate
extension WebViewController: WKNavigationDelegate {
    // 在这里处理需要的导航事件
}
