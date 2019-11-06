//
//  FriendRequestCell.swift
//  Tok
//
//  Created by Bryce on 2019/7/19.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import Reusable

class FriendRequestCell: UITableViewCell, NibLoadable {
    
    enum Status: Int, CustomStringConvertible {
        case waitting
        case refused
        case accepted
        
        var description: String {
            switch self {
            case .waitting:
                return NSLocalizedString("View", comment: "")
            case .refused:
                return NSLocalizedString("Refused", comment: "")
            case .accepted:
                return NSLocalizedString("Accepted", comment: "")
            }
        }
    }
    
    @IBOutlet weak var descLabel: UILabel!
    @IBOutlet weak var avatarImageView: UIImageView!
    @IBOutlet weak var topLabel: UILabel!
    var status: Status = .accepted {
        didSet {
            switch status {
            case .waitting:
                addButton.isHidden = false
                statusLabel.isHidden = true
            default:
                statusLabel.text = status.description
                addButton.isHidden = true
                statusLabel.isHidden = false
            }
        }
    }
    
    lazy var accessoryViewContainer: UIView = {
        let view = UIView()
        view.frame = accessoryViewFrame
        return view
    }()
    
    let accessoryViewFrame = CGRect(origin: .zero, size: CGSize(width: 90, height: 64))
    
    lazy var addButton: UIButton = {
        let button = UIButton()
        button.isUserInteractionEnabled = false
        button.setTitle(NSLocalizedString("Accept", comment: ""), for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 13)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.setBackgroundImage(UIColor.tokBlue.createImage(), for: .normal)
        button.setBackgroundImage(UIColor.tokBlue.withAlphaComponent(0.6).createImage(), for: .highlighted)
        button.layer.cornerRadius = 4
        button.layer.masksToBounds = true
        return button
    }()
    
    lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.frame = accessoryViewFrame
        label.textColor = UIColor.tokFootnote
        label.textAlignment = .right
        label.font = UIFont.systemFont(ofSize: 14)
        return label
    }()

    override func awakeFromNib() {
        super.awakeFromNib()
        accessoryView = accessoryViewContainer
        accessoryViewContainer.addSubview(addButton)
        addButton.snp.makeConstraints { (make) in
            make.centerY.trailing.equalToSuperview()
            make.size.equalTo(CGSize(width: 60, height: 30))
        }
        
        accessoryViewContainer.addSubview(statusLabel)
        statusLabel.snp.makeConstraints { (make) in
            make.centerY.trailing.equalToSuperview()
        }
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
}
