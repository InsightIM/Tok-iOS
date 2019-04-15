//
//  ChatTitleView.swift
//  Tok
//
//  Created by Bryce on 2018/7/8.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit

private struct Constants {
    static let StatusViewLeftOffset: CGFloat = 5.0
    static let StatusViewSize: CGFloat = 10.0
}

class ChatTitleView: UIView {

    var name: String {
        get {
            return nameLabel.text ?? ""
        }
        set {
            nameLabel.text = newValue
            
            updateFrame()
        }
    }
    
    var userStatus: UserStatus {
        get {
            return statusView.userStatus
        }
        set {
            statusView.userStatus = newValue
            statusLabel.text = newValue.toString()
            
            updateFrame()
        }
    }
    
    fileprivate var nameLabel: UILabel!
    fileprivate var statusView: UserStatusView!
    fileprivate var statusLabel: UILabel!
    
    init() {
        super.init(frame: CGRect.zero)
        
        backgroundColor = .clear
        
        createViews()
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension ChatTitleView {
    func createViews() {
        nameLabel = UILabel()
        nameLabel.textAlignment = .center
        nameLabel.textColor = UIColor.tokBlack
        nameLabel.font = UIFont.boldSystemFont(ofSize: 16)
        addSubview(nameLabel)
        
        statusView = UserStatusView()
        statusView.showExternalCircle = false
        addSubview(statusView)
        
        statusLabel = UILabel()
        statusLabel.textAlignment = .center
        statusLabel.textColor = UIColor.tokBlack
        statusLabel.font = UIFont.systemFont(ofSize: 12, weight: .light)
        addSubview(statusLabel)
        
        nameLabel.snp.makeConstraints {
            $0.top.equalTo(self)
            $0.leading.equalTo(self)
        }
        
        statusView.snp.makeConstraints {
            $0.centerY.equalTo(nameLabel)
            $0.leading.equalTo(nameLabel.snp.trailing).offset(Constants.StatusViewLeftOffset)
            $0.trailing.equalTo(self)
            $0.size.equalTo(Constants.StatusViewSize)
        }
        
        statusLabel.snp.makeConstraints {
            $0.top.equalTo(nameLabel.snp.bottom)
            $0.leading.equalTo(nameLabel)
            $0.trailing.equalTo(nameLabel)
            $0.bottom.equalTo(self)
        }
    }
    
    func updateFrame() {
        nameLabel.sizeToFit()
        statusLabel.sizeToFit()
        
        frame.size.width = max(nameLabel.frame.size.width, statusLabel.frame.size.width) + Constants.StatusViewLeftOffset + Constants.StatusViewSize
        frame.size.height = nameLabel.frame.size.height + statusLabel.frame.size.height
    }
}
