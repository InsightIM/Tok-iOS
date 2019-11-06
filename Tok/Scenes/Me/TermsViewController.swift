//
//  TermsViewController.swift
//  Tok
//
//  Created by Bryce on 2019/9/16.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import WebKit
import RxSwift
import RxCocoa

class TermsViewController: BaseViewController {

    let disposeBag = DisposeBag()
    
    lazy var webView: WKWebView = {
        let webView = WKWebView()
        return webView
    }()
    
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
        
        let termsText: String? = {
            let htmlFile = Bundle.main.path(forResource: "terms", ofType: "html")
            let htmlString = try? String(contentsOfFile: htmlFile!, encoding: .utf8)
            return htmlString
        }()
        let html = termsText!
        webView.loadHTMLString(html, baseURL: nil)
    }
}
