//
//  DiscoverProfileView.swift
//  Tok
//
//  Created by Bryce on 2019/7/1.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit

class DiscoverProfileView: UIView {

    @IBOutlet weak var avatarImageView: UIImageView! {
        didSet {
            avatarImageView.layer.cornerRadius = AvatarConstants.CornerRadius
            avatarImageView.layer.masksToBounds = true
        }
    }
    @IBOutlet weak var myStyle: UILabel! {
        didSet {
            myStyle.text = NSLocalizedString("My Style", comment: "")
        }
    }
}
