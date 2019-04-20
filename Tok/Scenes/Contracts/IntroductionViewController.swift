//
//  IntroductionViewController.swift
//  Tok
//
//  Created by Bryce on 2019/4/20.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import WebKit

class IntroductionViewController: BaseViewController {
    
    lazy var webView: WKWebView = {
        let preferences = WKPreferences()
        preferences.javaScriptEnabled = true
        
        let configuration = WKWebViewConfiguration()
        configuration.preferences = preferences
        configuration.userContentController = WKUserContentController()
        configuration.userContentController.add(self, name: "Tok")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        return webView
    }()
    
    let css =
    """
<style>
body, html {
    font-family: Roboto,sans-serif;
    color: #000;
    margin: 0;
    padding: 0;
}
html {
    line-height: 1.15;
}
div {
    display: block;
}
h2 {
    font-family: Roboto,sans-serif;
    font-size: 16px;
    font-weight: bold;
    margin-bottom: -10px;
}
.page.layout .content {
    box-sizing: border-box;
    width: 100%;
    max-width: 640px;
    padding: 64px 24px;
    padding-top: 16px;
    margin: 0 auto;
}
section {
    display: block;
}
.page.layout .content p {
    margin: 16px 0;
    line-height: 1.5em;
    font-size: 16px;
    font-weight: 300;
}
p {
    display: block;
    margin-block-start: 1em;
    margin-block-end: 1em;
    margin-inline-start: 0px;
    margin-inline-end: 0px;
}
.page.layout .content ol {
    margin: 16px 0;
    line-height: 1.5em;
    font-size: 16px;
    font-weight: 300;
}
img {
    border-style: none;
    width: 100%;
    max-width: 260px;
}
.warning {
    color: #EE0000;
}
</style>
    
"""
    let script = """
<script type="text/javascript">
function copyLink(arg) {
    window.webkit.messageHandlers.Tok.postMessage(arg);
}
</script>
"""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        titleString = NSLocalizedString("OfflineMessageBot", comment: "")
        
        view.addSubview(webView)
        webView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        let introText = NSLocalizedString("offlinebot_intro", comment: "")
        let imgBase64 = UIImage(named: "OfflinebotIntro")?.jpegData(compressionQuality: 1.0)?.base64EncodedString() ?? ""
        let body = introText.replacingOccurrences(of: "$image$", with: imgBase64)
        let html = "<html><meta name=\"viewport\" content=\"width=device-width\">\(css)\(script)\(body)</html>"
        webView.loadHTMLString(html, baseURL: nil)
        
    }
}

extension IntroductionViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let link = message.body as? String else {
            return
        }
        UIPasteboard.general.string = link
        ProgressHUD.showTextHUD(withText: NSLocalizedString("The link has been copied to the clipboard", comment: ""), in: self.view)
    }
}
