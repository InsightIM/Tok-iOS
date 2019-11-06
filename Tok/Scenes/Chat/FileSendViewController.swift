//
//  FileSendViewController.swift
//  Tok
//
//  Created by Bryce on 2018/10/3.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit
import WebKit
import RxSwift

class FileSendViewController: BaseViewController {

    private let disposeBag = DisposeBag()
    
    lazy var sendItem: UIBarButtonItem = {
        let item = UIBarButtonItem(image: UIImage(named: "Send"), style: .plain, target: nil, action: nil)
        return item
    }()
    
    lazy var webView: WKWebView = {
        let config = WKWebViewConfiguration()
        config.mediaTypesRequiringUserActionForPlayback = .all
        let webView = WKWebView(frame: self.view.frame, configuration: config)
        return webView
    }()
    
    private let documentUrl: URL
    private let dataSource: ConversationDataSource
    
    init(documentUrl: URL, dataSource: ConversationDataSource) {
        self.documentUrl = documentUrl
        self.dataSource = dataSource
        
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = documentUrl.lastPathComponent.substring(endChar:  ".")
        
        navigationItem.rightBarButtonItem = sendItem
        
        view.addSubview(webView)
        webView.snp.makeConstraints({ (make) in
            make.edges.equalToSuperview()
        })
        webView.loadFileURL(documentUrl, allowingReadAccessTo: documentUrl)
        
        sendItem.rx.tap
            .subscribe(onNext: { [unowned self] _ in
                self.dataSource.addFileMessage(url: self.documentUrl)
                self.navigationController?.popViewController(animated: true)
            })
            .disposed(by: disposeBag)
    }
}
