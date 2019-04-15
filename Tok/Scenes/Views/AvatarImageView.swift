import UIKit

class AvatarImageView: UIImageView {
    
    @IBInspectable var cornerRadius: CGFloat {
        get {
            return layer.cornerRadius
        }
        
        set {
            layer.cornerRadius = newValue
            layer.masksToBounds = newValue > 0
        }
    }
    
    @IBInspectable
    var titleFontSize: CGFloat = 17 {
        didSet {
            titleLabel?.font = .systemFont(ofSize: titleFontSize)
        }
    }
    var titleLabel: UILabel!

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    init() {
        super.init(frame: .zero)
        prepare()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        prepare()
    }

    func setGroupImage(avatar: UIImage?) {
        backgroundColor = .clear
        titleLabel.text = nil
        image = avatar
    }

    func setFriendImage(friend: OCTFriend?) {
        guard let friend = friend else {
            setImage(with: nil, identityNumber: 0, name: "?")
            return
        }
        
        setImage(with: friend.avatarData, identityNumber: Int(friend.friendNumber), name: friend.nickname)
    }
    
    func setImage(peer: OCTPeer) {
        let identityNumber: Int = Int(arc4random() % 8 + 1)
        setImage(with: peer.avatarData, identityNumber: identityNumber, name: peer.nickname)
    }
    
    func setImage(with data: Data?, identityNumber: Int, name: String?) {
        if let data = data, data.count > 0 {
            titleLabel.text = nil
            backgroundColor = .clear
            image = UIImage(data: data)
        } else {
            image = UIImage(named: "color\(identityNumber % 8 + 1)")
            backgroundColor = .clear

            if let name = name, let firstLetter = name.first {
                titleLabel.text = String([firstLetter]).uppercased()
            } else {
                titleLabel.text = "?"
            }
        }
    }

    private func prepare() {
        titleLabel = UILabel()
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: titleFontSize)
        contentMode = .scaleAspectFill
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { (make) in
            make.center.equalToSuperview()
        }
        
        cornerRadius = AvatarConstants.CornerRadius
    }
    
}

extension UIImageView {
    func setAvatar(by avatarImage: UIImage?, text: String?) {
        let updateBlock: (UIImageView, UILabel) -> Void = { imageView, label in
            imageView.image = avatarImage
            label.text = text
        }
        
        if let label = viewWithTag(333777) as? UILabel {
            updateBlock(self, label)
            return
        }
        
        let titleLabel = UILabel()
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 17)
        titleLabel.tag = 333777
        contentMode = .scaleAspectFill
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { (make) in
            make.center.equalToSuperview()
        }
        
        backgroundColor = .clear
        layer.cornerRadius = AvatarConstants.CornerRadius
        layer.masksToBounds = AvatarConstants.CornerRadius > 0
        
        updateBlock(self, titleLabel)
    }
    
    func setImageData(with data: Data?, identityNumber: Int, name: String?) {
        if let data = data, let image = UIImage(data: data) {
            setAvatar(by: image, text: nil)
        } else {
            let image = UIImage(named: "color\(identityNumber % 8 + 1)")
            
            if let name = name, let firstLetter = name.first {
                let text = String([firstLetter]).uppercased()
                setAvatar(by: image, text: text)
            } else {
                setAvatar(by: image, text: "?")
            }
        }
    }
    
    func setImage(by friend: OCTFriend?) {
        guard let friend = friend else {
            setImageData(with: nil, identityNumber: 0, name: "?")
            return
        }
        
        setImageData(with: friend.avatarData, identityNumber: Int(friend.friendNumber), name: friend.nickname)
    }
    
    func setImage(by peer: OCTPeer) {
        let identityNumber: Int = Int(arc4random() % 8 + 1)
        setImageData(with: peer.avatarData, identityNumber: identityNumber, name: peer.nickname)
    }
    
    func setImage(by chat: OCTChat) {
        if chat.isGroup {
            setAvatar(by: AvatarManager.shared.groupAvatar(for: chat), text: nil)
        } else {
            setImage(by: chat.friends?.firstObject() as? OCTFriend)
        }
    }
}
