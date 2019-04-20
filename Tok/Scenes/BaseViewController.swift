//
//  BaseViewController.swift
//  Tok
//
//  Created by Bryce on 2018/6/14.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit

class BaseViewController: UIViewController {
    
    public var prefersNavigationBarHidden: Bool = false
    
    public var largeTitleDisplay: Bool = false {
        didSet {
            if #available(iOS 11.0, *) {
                if largeTitleDisplay {
                    navigationItem.largeTitleDisplayMode = .always
                } else {
                    navigationItem.largeTitleDisplayMode = .never
                }
            }
        }
    }
    
    var titleString: String? = nil {
        didSet {
            title = ""
            
            let titleLabel = UILabel()
            titleLabel.font = UIFont.systemFont(ofSize: 17, weight: .medium)
            titleLabel.textColor = .tokBlack
            titleLabel.text = titleString
            navigationItem.titleView = titleLabel
        }
    }
    
    init() {
        super.init(nibName: nil, bundle: nil)
        edgesForExtendedLayout = UIRectEdge()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor.white
        
        if #available(iOS 11.0, *) {
            if largeTitleDisplay {
                navigationItem.largeTitleDisplayMode = .always
            } else {
                navigationItem.largeTitleDisplayMode = .never
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.navigationBar.isTranslucent = self.largeTitleDisplay
        
        navigationController?.setNavigationBarHidden(prefersNavigationBarHidden, animated: animated)
        if #available(iOS 11.0, *) {
            navigationController?.navigationBar.prefersLargeTitles = true
        } else {
            navigationController?.navigationBar.isTranslucent = false
        }
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .default
    }
    
    deinit {
        print("👍👍👍===== \(self) deinit =====👍👍👍")
    }
}
