//
//  MyInfoView.swift
//  Tok
//
//  Created by Bryce on 2019/7/10.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit

class MyInfoView: UIView {

    var didClickShare: (() -> Void)?
    
    @IBOutlet weak var avatarImageView: UIImageView! {
        didSet {
            avatarImageView.layer.cornerRadius = AvatarConstants.CornerRadius
            avatarImageView.layer.masksToBounds = true
        }
    }
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var bioLabel: UILabel!
    @IBOutlet weak var qrcodeImageView: UIImageView!
    @IBOutlet weak var shareButton: UIButton! {
        didSet {
            shareButton.fcBorderStyle(title: NSLocalizedString("Share", comment: ""), color: UIColor("#007AFF"), bgColor: .white, borderWidth: 1)
        }
    }
    @IBAction func didShare(_ sender: UIButton) {
        didClickShare?()
    }
}
