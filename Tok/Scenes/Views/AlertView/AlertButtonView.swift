//
//  AlertView.swift
//  Tok
//
//  Created by Bryce on 2019/1/22.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import SwiftMessages

class AlertButtonView: MessageView {
    
    @IBOutlet weak var cancelButton: UIButton! {
        didSet {
            cancelButton.setSheetButtonStyle(title: NSLocalizedString("Cancel", comment: ""), style: .cancel)
        }
    }
    
    @IBOutlet weak var stackView: UIStackView!
    
    @IBAction func cancelClick(_ sender: UIButton) {
        SwiftMessages.hide()
    }
}
