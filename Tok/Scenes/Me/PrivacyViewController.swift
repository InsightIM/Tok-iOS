//
//  PrivacyViewController.swift
//  Tok
//
//  Created by Bryce on 2019/1/29.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import WebKit
import RxSwift
import RxCocoa

class PrivacyViewController: BaseViewController {
    
    let disposeBag = DisposeBag()
    
    lazy var webView: WKWebView = {
        let webView = WKWebView()
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
.page.layout .header {
    box-sizing: border-box;
    width: 100%;
    height: 96px;
    border-bottom: 1px solid rgba(0,0,0,.1);
    position: relative;
    text-align: center;
}
.page.layout .header .title {
    font-family: Roboto,sans-serif;
    display: inline-block;
    font-size: 24px;
    font-weight: 300;
    line-height: 96px;
    margin: 0;
    padding: 0;
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
    padding-top: 32px;
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
.page.layout .footer.logo {
    text-align: center;
    padding-bottom: 64px;
}
.page.layout .footer.logo img:hover {
    opacity: 1;
}
.page.layout .footer.logo img {
    width: 64px;
    height: 64px;
    margin-top: 16px;
    opacity: .3;
}
img {
    border-style: none;
}
</style>
    
"""
    let privacyText = NSLocalizedString("privacy_text", comment: "")
    
    lazy var backButton: UIButton = {
        let backButton = UIButton(type: .system)
        backButton.tintColor = .tokBlack
        backButton.setImage(UIImage(named: "Close"), for: .normal)
        return backButton
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        webView.scrollView.rx.contentOffset
            .subscribe(onNext: { [weak self] offset in
                guard let self = self else { return }
                if offset.y < (-120 - UIApplication.safeAreaInsets.top) {
                    self.dismiss(animated: true, completion: nil)
                }
                
                if offset.y > 50 {
                    if self.backButton.alpha == 0 {
                        return
                    }
                    UIView.animate(withDuration: 0.25, animations: {
                        self.backButton.alpha = 0
                    })
                } else {
                    if self.backButton.alpha == 1 {
                        return
                    }
                    UIView.animate(withDuration: 0.25, animations: {
                        self.backButton.alpha = 1
                    })
                }
            })
            .disposed(by: disposeBag)
        
        view.addSubview(webView)
        webView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        view.addSubview(backButton)
        backButton.snp.makeConstraints { (make) in
            make.top.equalTo(self.view.safeArea.top).offset(10)
            make.right.equalTo(-10)
            make.size.equalTo(20)
        }
        
        backButton.rx.tap
            .subscribe(onNext: { [weak self] _ in
                guard let self = self else { return }
                self.dismiss(animated: true, completion: nil)
            })
            .disposed(by: disposeBag)

        var logoDiv = ""
        if let logo = UIImage(named: "logo")?.jpegData(compressionQuality: 1.0)?.base64EncodedString() {
            logoDiv = "<div class=\"logo footer\"><img src=\"data:image/jpeg;base64,\(logo)\" alt=\"Logo\"></div>"
        }
        
        let html = "<html><meta name=\"viewport\" content=\"width=device-width\">\(css)\(privacyText)\(logoDiv)</html>"
        webView.loadHTMLString(html, baseURL: nil)
        
    }
}
