// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import UIKit
import SnapKit
import RxSwift

class QRViewerController: BaseViewController {
    
    fileprivate let disposeBag = DisposeBag()
    
    fileprivate let text: String

    fileprivate var previousBrightness: CGFloat = 1.0

    fileprivate var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
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
    
    lazy var inviteButton: UIButton = {
        let button = UIButton()
        button.fcStyle(title: NSLocalizedString("Invite Friend", comment: ""), cornerRadius: 0)
        return button
    }()
    
    init(text: String) {
        self.text = text
        
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
        imageView.image = qrImageFromText()
        
        copyButton.rx.tap
            .subscribe(onNext: { [unowned self] _ in
                UIPasteboard.general.string = self.text
                ProgressHUD.showTextHUD(withText: NSLocalizedString("Your ID has been copied to the clipboard", comment: ""), in: self.view, afterDelay: 1.5)
            })
            .disposed(by: disposeBag)
        
        inviteButton.rx.tap
            .subscribe(onNext: { [unowned self] _ in
                self.presentInvite()
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
        
        view.addSubview(imageView)
        imageView.snp.makeConstraints { (make) in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-30)
            make.size.equalTo(CGSize(width: 200, height: 200))
        }
        
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
    }
    
    func qrImageFromText() -> UIImage {
        let filter = CIFilter(name:"CIQRCodeGenerator")!
        filter.setDefaults()
        filter.setValue(text.data(using: String.Encoding.utf8), forKey: "inputMessage")

        let ciImage = filter.outputImage!
        let screenBounds = UIScreen.main.bounds

        let scale = min(screenBounds.size.width / ciImage.extent.size.width, screenBounds.size.height / ciImage.extent.size.height)
        let transformedImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        return UIImage(ciImage: transformedImage)
    }
}
