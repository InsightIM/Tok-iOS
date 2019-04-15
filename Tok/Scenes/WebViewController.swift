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
        
        view.addSubview(webView)
        webView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        if let url = url {
            webView.loadFileURL(url, allowingReadAccessTo: url)
        }
    }
}
