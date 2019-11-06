//
//  WebViewController.swift
//  Tok
//
//  Created by Bryce on 2018/10/31.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit
import WebKit

class WebViewController: BaseViewController {
    
    let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
    var url: URL?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        webView.navigationDelegate = self
        view.addSubview(webView)
        webView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        if let url = url {
            webView.loadFileURL(url, allowingReadAccessTo: url)
        }
    }
}

extension WebViewController: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        ProgressHUD.showLoadingHUD(in: view)
    }
    
    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        title = webView.title
        ProgressHUD.hideLoadingHUD(in: view)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        ProgressHUD.hideLoadingHUD(in: view)
    }
}
