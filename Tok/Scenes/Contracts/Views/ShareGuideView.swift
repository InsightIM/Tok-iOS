//
//  ShareGuideView.swift
//  Tok
//
//  Created by Bryce on 2019/7/9.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit

class ShareGuideView: UIView {

    @IBOutlet weak var step1Label: UILabel! {
        didSet {
            step1Label.text = NSLocalizedString("Save to gallery", comment: "")
        }
    }
    
    @IBOutlet weak var step2Label: UILabel! {
        didSet {
            step2Label.text = NSLocalizedString("Scan to download", comment: "")
        }
    }
    
    @IBOutlet weak var step3Label: UILabel! {
        didSet {
            step3Label.text = NSLocalizedString("Scan again to add me on Tok", comment: "")
            step3Label.adjustsFontSizeToFitWidth = true
            step3Label.baselineAdjustment = .alignCenters
        }
    }
}
