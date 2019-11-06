//
//  NoMoreStrangerViewController.swift
//  Tok
//
//  Created by Bryce on 2019/7/4.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit

class NoMoreStrangerViewController: BaseViewController {

    lazy var emptyImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "NoMoreStranger")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    lazy var tipLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor("#B5B5BB")
        label.font = UIFont.systemFont(ofSize: 17)
        label.text = NSLocalizedString("No more, please come back tomorrow", comment: "")
        label.numberOfLines = 0
        return label
    }()
    
    lazy var sendStartButton: UIButton = {
        let button = UIButton()
        button.fcBorderStyle(title: NSLocalizedString("Show me", comment: ""))
        button.addTarget(self, action: #selector(self.didClick), for: .touchUpInside)
        return button
    }()
    
    private let findFriendService: FindFriendService
    init(findFriendService: FindFriendService) {
        self.findFriendService = findFriendService
        super.init()
        hidesBottomBarWhenPushed = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Neverland", comment: "")
        
        view.addSubview(emptyImageView)
        view.addSubview(tipLabel)
        
        emptyImageView.snp.makeConstraints { (make) in
            make.centerY.equalToSuperview().multipliedBy(0.7)
            make.centerX.equalToSuperview()
            make.size.equalTo(CGSize(width: 91, height: 79))
        }
        tipLabel.snp.makeConstraints { (make) in
            make.top.equalTo(emptyImageView.snp.bottom).offset(20)
            make.centerX.equalToSuperview()
        }
        
        if findFriendService.isAnonymous {
            view.addSubview(sendStartButton)
            sendStartButton.snp.makeConstraints { (make) in
                make.height.equalTo(44)
                make.leading.equalTo(20)
                make.trailing.equalTo(-20)
                make.bottom.equalTo(self.view.safeArea.bottom).offset(-40)
            }
        }
    }
    
    @objc
    func didClick() {
        findFriendService.sendStart()
        if let first = navigationController?.viewControllers.first {
            let vc = NeverlandMeViewController(findFriendService: findFriendService)
            navigationController?.setViewControllers([first, vc], animated: true)
        }
    }
}
