//
//  RedPointView.swift
//  Tok
//
//  Created by lbowen on 2019/9/25.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit

class RedPointView: UILabel {

    override init(frame: CGRect) {
        super.init(frame: .zero)
        
        self.backgroundColor = .red
        self.textColor = .white
        self.textAlignment = .center
        self.layer.masksToBounds = true
        self.layer.cornerRadius = 4
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
