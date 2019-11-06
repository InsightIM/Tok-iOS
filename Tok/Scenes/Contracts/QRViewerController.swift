// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import UIKit
import SnapKit
import RxSwift
import Device

class QRViewerController: BaseViewController {
    
    fileprivate let disposeBag = DisposeBag()
    
    fileprivate let text: String

    fileprivate var previousBrightness: CGFloat = 1.0

    fileprivate var infoView: MyInfoView = {
        let view = UIView.ts_viewFromNib(MyInfoView.self)
        view.layer.cornerRadius = 8
        view.layer.masksToBounds = true
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 5, height: 5)
        view.layer.shadowOpacity = 0.8
        return view
    }()
    
    lazy var idLabel: UILabel = {
        let label = UILabel()
        label.copyable = true
        label.font = UIFont.systemFont(ofSize: 15)
        label.textColor = UIColor.tokBlack
        label.numberOfLines = 0
        return label
    }()
    
    lazy var tipLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 15)
        label.textColor = UIColor.tokBlack
        label.text = NSLocalizedString("My Tok ID", comment: "")
        return label
    }()
    
    lazy var copyButton: UIButton = {
        let button = UIButton()
        button.setTitle(NSLocalizedString("Copy", comment: ""), for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 15)
        button.setTitleColor(UIColor.tokLink, for: .normal)
        button.setTitleColor(UIColor.tokLink.withAlphaComponent(0.4), for: .highlighted)
        return button
    }()
    
    lazy var descButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        button.titleLabel?.numberOfLines = 0
        
        let text = NSLocalizedString("TOK_ID_Desc", comment: "")
        let attributedText = NSMutableAttributedString(string: text, attributes: [.foregroundColor: UIColor.tokFootnote])
//        let moreText = NSAttributedString(string: "了解详情 >", attributes: [.foregroundColor: UIColor.tokLink])
//        attributedText.append(moreText)
        
        button.setAttributedTitle(attributedText, for: .normal)
        return button
    }()
    
    let messageService: MessageService
    init(messageService: MessageService) {
        self.messageService = messageService
        self.text = messageService.tokManager.tox.userAddress
        super.init()
        
        hidesBottomBarWhenPushed = true
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = NSLocalizedString("My Tok ID", comment: "")
        view.backgroundColor = UIColor.tokBackgroundColor
        
        createViews()
        idLabel.text = text
        infoView.avatarImageView.image = AvatarManager.shared.userAvatar(messageService: messageService)
        infoView.nameLabel.text = UserService.shared.nickName
        infoView.bioLabel.text = UserService.shared.statusMessage
        let icon = UIImage(named: "TokQrcode")!
        let image = UIImage.createCustomizeQRCode(size: 200, dataStr: text, imageType: .SquareImage, iconImage: icon, iconImageSize: 50)
        infoView.qrcodeImageView.image = image
        infoView.didClickShare = { [unowned self] in
            self.presentInvite(messageService: self.messageService)
        }
        
        copyButton.rx.tap
            .subscribe(onNext: { [unowned self] _ in
                UIPasteboard.general.string = self.text
                ProgressHUD.showTextHUD(withText: NSLocalizedString("Your ID has been copied to the clipboard", comment: ""), in: self.view, afterDelay: 1.5)
            })
            .disposed(by: disposeBag)
        
        descButton.rx.tap
            .subscribe(onNext: { [unowned self] _ in
                self.presentPrivacy()
            })
            .disposed(by: disposeBag)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        previousBrightness = UIScreen.main.brightness
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        UIScreen.main.brightness = previousBrightness
    }
}

private extension QRViewerController {
    func createViews() {
        view.addSubview(tipLabel)
        tipLabel.snp.makeConstraints { (make) in
            make.top.equalTo(20)
            make.left.equalTo(20)
        }
        
        view.addSubview(copyButton)
        copyButton.snp.makeConstraints { (make) in
            make.right.equalTo(-20)
            make.centerY.equalTo(tipLabel)
        }
        
        let bgView = UIView()
        bgView.layer.borderWidth = 1.0 / UIScreen.main.scale
        bgView.layer.borderColor = UIColor.tokLine.cgColor
        bgView.backgroundColor = UIColor.white
        view.addSubview(bgView)
        bgView.snp.makeConstraints { (make) in
            make.left.right.equalToSuperview()
            make.top.equalTo(tipLabel.snp.bottom).offset(8)
        }
        
        bgView.addSubview(idLabel)
        idLabel.snp.makeConstraints { (make) in
            make.left.equalTo(20)
            make.right.equalTo(-20)
            make.top.equalTo(15)
            make.bottom.equalTo(-15)
        }
        
        view.addSubview(descButton)
        descButton.snp.makeConstraints { (make) in
            make.left.equalTo(20)
            make.right.equalTo(-20)
            make.top.equalTo(bgView.snp.bottom).offset(10)
        }
        
        view.addSubview(infoView)
        infoView.snp.makeConstraints { (make) in
            let topOffset = Device.size() < .screen5_5Inch ? 10 : 40
            make.top.equalTo(descButton.snp.bottom).offset(topOffset)
            make.centerX.equalToSuperview()
            make.leading.equalTo(20)
            make.trailing.equalTo(-20)
        }
    }
}
