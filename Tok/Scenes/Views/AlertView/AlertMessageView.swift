//
//  AlertMessageView.swift
//  Tok
//
//  Created by Bryce on 2019/1/23.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import SwiftMessages

class AlertMessageView: MessageView {
    var customCancelAction: (() -> Void)?
    
    @IBOutlet weak var containerView: UIView! {
        didSet {
            containerView.addBottomLine()
        }
    }
    
    @IBOutlet weak var messageLabel: UILabel! {
        didSet {
            messageLabel.font = UIFont.systemFont(ofSize: 15)
            messageLabel.textColor = UIColor("#888888")
        }
    }
    
    @IBOutlet weak var cancelButton: UIButton! {
        didSet {
            cancelButton.setSheetButtonStyle(title: NSLocalizedString("Cancel", comment: ""), style: .cancel)
        }
    }
    
    @IBOutlet weak var stackView: UIStackView!
    
    @IBAction func cancelClick(_ sender: UIButton) {
        customCancelAction?()
        SwiftMessages.hide()
    }
}
