//
//  InviteFriendViewController.swift
//  Tok
//
//  Created by Bryce on 2019/1/27.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import Photos
import Device

let officalLink = "https://www.tok001.life"
let officalDomain = "tok001.life"

class InviteFriendViewController: BaseViewController {
    
    private let disposeBag = DisposeBag()

    lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 8
        view.layer.masksToBounds = true
        view.layer.shadowColor = UIColor.black.withAlphaComponent(0.3).cgColor
        return view
    }()
    
    lazy var avatarImageView: UIImageView = UIImageView()
    
    lazy var descriptionLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.tokBlack
        label.font = UIFont.systemFont(ofSize: 16)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    lazy var qrcodeTipLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.tokFootnote
        label.font = UIFont.systemFont(ofSize: 14)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.text = NSLocalizedString("Scan the QR code to add me on Tok", comment: "")
        return label
    }()
    
    private var qrcodeImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private var shareTextButton: UIButton = {
        let button = UIButton()
        button.setTitle(NSLocalizedString("Share by Text", comment: ""), for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 17)
        button.setTitleColor(.tokBlue, for: .normal)
        button.setTitleColor(UIColor.tokBlue.withAlphaComponent(0.5), for: .highlighted)
        return button
    }()
    
    private var shareImageButton: UIButton = {
        let button = UIButton()
        button.fcStyle(title: NSLocalizedString("Share by Image", comment: ""))
        return button
    }()
    
    lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        return scrollView
    }()
    
    let messageService: MessageService
    init(messageService: MessageService) {
        self.messageService = messageService
        super.init()
        
        hidesBottomBarWhenPushed = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Invite to Tok", comment: "")
        view.backgroundColor = .tokBackgroundColor
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(named: "Back"), style: .plain, target: self, action: #selector(self.didBack))
        
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { (make) in
            make.left.equalTo(20)
            make.right.equalTo(-20)
            make.top.equalTo(self.view.safeArea.top).offset(12)
        }
        
        scrollView.addSubview(containerView)
        containerView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
            make.width.equalToSuperview()
        }
        
        avatarImageView.layer.cornerRadius = AvatarConstants.CornerRadius
        avatarImageView.layer.masksToBounds = true
        containerView.addSubview(avatarImageView)
        avatarImageView.snp.makeConstraints { (make) in
            make.size.equalTo(68)
            make.centerX.equalToSuperview()
            make.top.equalTo(Device.size() < .screen5_5Inch ? 20 : 50)
        }
        
        containerView.addSubview(descriptionLabel)
        descriptionLabel.snp.makeConstraints { (make) in
            make.top.equalTo(avatarImageView.snp.bottom).offset(20)
            make.left.equalTo(20)
            make.right.equalTo(-20)
        }
        
        containerView.addSubview(qrcodeImageView)
        qrcodeImageView.snp.makeConstraints { (make) in
            make.centerX.equalToSuperview()
            make.top.equalTo(descriptionLabel.snp.bottom).offset(Device.size() < .screen5_5Inch ? 20 : 50)
            make.size.equalTo(200)
        }
        
        containerView.addSubview(qrcodeTipLabel)
        qrcodeTipLabel.snp.makeConstraints { (make) in
            make.top.equalTo(qrcodeImageView.snp.bottom).offset(8)
            make.centerX.equalToSuperview()
            make.left.greaterThanOrEqualTo(20)
            make.right.lessThanOrEqualTo(-20)
            make.bottom.equalTo(-40)
        }
        
        view.addSubview(shareTextButton)
        view.addSubview(shareImageButton)
        
        shareTextButton.snp.makeConstraints { (make) in
            make.leading.equalTo(20)
            make.trailing.equalTo(-20)
            make.bottom.equalTo(self.view.safeArea.bottom).offset(-20)
            make.height.equalTo(50)
        }
        
        shareImageButton.snp.makeConstraints { (make) in
            make.leading.equalTo(20)
            make.trailing.equalTo(-20)
            make.bottom.equalTo(shareTextButton.snp.top).offset(-15)
            make.height.equalTo(50)
            make.top.equalTo(scrollView.snp.bottom).offset(20)
        }
        
        containerView.snp.updateConstraints { (make) in
            make.bottom.equalToSuperview()
        }
        
        avatarImageView.image = AvatarManager.shared.userAvatar(messageService: messageService)
        
        descriptionLabel.text = String(format: NSLocalizedString("Hello，I'm %@\nI'm in Tok，peer-to-peer encrypted chat!", comment: ""), UserService.shared.nickName ?? "Tok")
        
        let qrtext = "\(officalLink)?toxid=\(UserService.shared.toxMananger!.user.userAddress)"
        let icon = UIImage(named: "TokQrcode")!
        let image = UIImage.createCustomizeQRCode(size: 200, dataStr: qrtext, imageType: .SquareImage, iconImage: icon, iconImageSize: 50)
        qrcodeImageView.image = image
        
        shareTextButton.rx.tap
            .subscribe(onNext: { [unowned self] _ in
                let text = String(format: NSLocalizedString("Peer-to-peer encrypted chat, I’m in Tok, click %@, free download Tok app. If you installed it, please copy this text $%@$, open Tok can add me as friends.", comment: ""), officalLink, UserService.shared.toxMananger!.user.userAddress)
                
                UIPasteboard.general.string = text
                ProgressHUD.showTextHUD(withText: NSLocalizedString("The text has been copied to the clipboard", comment: ""), in: self.view, afterDelay: 2)
            })
            .disposed(by: disposeBag)
        
        shareImageButton.rx.tap
            .subscribe(onNext: { [unowned self] _ in
                guard let image = self.bulidShareImage() else {
                    return
                }
                
                let items: [Any] = [image]
                let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
                self.present(vc, animated: true, completion: nil)
            })
            .disposed(by: disposeBag)
    }
    
    // MARK: - Private Methods
    
    @objc
    private func didBack() {
        self.dismiss(animated: true, completion: nil)
    }
    
    private func qrImageFromText(text: String) -> UIImage {
        let filter = CIFilter(name:"CIQRCodeGenerator")!
        filter.setDefaults()
        filter.setValue(text.data(using: String.Encoding.utf8), forKey: "inputMessage")
        
        let ciImage = filter.outputImage!
        let screenBounds = UIScreen.main.bounds
        
        let scale = min(screenBounds.size.width / ciImage.extent.size.width, screenBounds.size.height / ciImage.extent.size.height)
        let transformedImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        
        return UIImage(ciImage: transformedImage)
    }
    
    private func bulidShareImage() -> UIImage? {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height * 2))
        
        let contentView = UIView()
        contentView.backgroundColor = UIColor("#F5F6FA")
        view.addSubview(contentView)
        contentView.snp.makeConstraints { (make) in
            make.top.equalToSuperview()
            make.left.right.equalToSuperview()
            make.bottom.lessThanOrEqualToSuperview()
        }
        
        let containerView: UIView = {
            let view = UIView()
            view.backgroundColor = .white
            return view
        }()
        
        let avatarImageView: UIImageView = UIImageView()
        
        let descriptionLabel: UILabel = {
            let label = UILabel()
            label.textColor = UIColor.tokBlack
            label.font = UIFont.systemFont(ofSize: 16)
            label.textAlignment = .center
            label.numberOfLines = 0
            return label
        }()
        
        let qrcodeImageView: UIImageView = {
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFit
            return imageView
        }()
        
        let shareTextLabel: UILabel = {
            let label = UILabel()
            label.textColor = UIColor.tokFootnote
            label.font = UIFont.systemFont(ofSize: 14)
            label.textAlignment = .center
            label.numberOfLines = 0
            label.text = NSLocalizedString("Scan the QR code to add me on Tok", comment: "")
            return label
        }()
        
        let guideView: UIView = {
            return UIView.ts_viewFromNib(ShareGuideView.self)
        }()
        
        contentView.addSubview(containerView)
        containerView.snp.makeConstraints { (make) in
            make.leading.trailing.top.equalToSuperview()
        }
        
        avatarImageView.layer.cornerRadius = AvatarConstants.CornerRadius
        avatarImageView.layer.masksToBounds = true
        avatarImageView.image = AvatarManager.shared.userAvatar(messageService: messageService)
        containerView.addSubview(avatarImageView)
        avatarImageView.snp.makeConstraints { (make) in
            make.size.equalTo(68)
            make.centerX.equalToSuperview()
            make.top.equalTo(50)
        }
        
        descriptionLabel.text = self.descriptionLabel.text
        containerView.addSubview(descriptionLabel)
        descriptionLabel.snp.makeConstraints { (make) in
            make.top.equalTo(avatarImageView.snp.bottom).offset(20)
            make.left.equalTo(20)
            make.right.equalTo(-20)
        }
        
        qrcodeImageView.image = self.qrcodeImageView.image
        containerView.addSubview(qrcodeImageView)
        qrcodeImageView.snp.makeConstraints { (make) in
            make.centerX.equalToSuperview()
            make.top.equalTo(descriptionLabel.snp.bottom).offset(50)
            make.size.equalTo(200)
        }
        
        containerView.addSubview(shareTextLabel)
        shareTextLabel.snp.makeConstraints { (make) in
            make.top.equalTo(qrcodeImageView.snp.bottom).offset(50)
            make.left.equalTo(10)
            make.right.equalTo(-10)
            make.bottom.equalTo(-36)
        }
        
        contentView.addSubview(guideView)
        guideView.snp.makeConstraints { (make) in
            make.top.equalTo(containerView.snp.bottom).offset(40)
            make.height.equalTo(80)
            make.leading.equalTo(30)
            make.trailing.equalTo(-30)
            make.bottom.equalTo(-40)
        }
        
        contentView.layoutIfNeeded()
        
        let bgView = UIView()
        bgView.backgroundColor = UIColor.tokBackgroundColor
        contentView.insertSubview(bgView, at: 0)
        
        let image = contentView.screenshot()
        return image
    }
    
    private func saveToLibrary() {
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
        case .notDetermined:
            DispatchQueue.global(qos: .default).async {
                PHPhotoLibrary.requestAuthorization({ (status) in
                    if status == .authorized {
                        DispatchQueue.main.async {
                            self.performSavingToLibrary()
                        }
                    }
                })
            }
        case .denied, .restricted:
            requirePhotoAuthorization()
        case .authorized:
            performSavingToLibrary()
        @unknown default:
            break
        }
    }
    
    private func performSavingToLibrary() {
        guard let image = containerView.screenshot() else {
            return
        }
        
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }, completionHandler: { [weak self] (success, error) in
            DispatchQueue.main.async {
                if success {
                    ProgressHUD.showTextHUD(withText: "Image saved successfully", in: self?.view)
                } else {
                    ProgressHUD.showTextHUD(withText: "Failed to save the image", in: self?.view)
                }
            }
        })
    }
    
    private func requirePhotoAuthorization() {
        showAlert(message: NSLocalizedString("Please ensure photo permissions are granted for Tok. You can check by going to \"Settings -> Privacy -> Photos\"", comment: ""))
    }
    
    private func showAlert(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: nil)
        alert.addAction(cancelAction)
        
        let settingAction = UIAlertAction(title: NSLocalizedString("Settings", comment: ""), style: .default) { (_) in
            let url = URL(string: UIApplication.openSettingsURLString)
            if let url = url,
                UIApplication.shared.canOpenURL(url) {
                if #available(iOS 10.0, *) {
                    UIApplication.shared.open(url, options: convertToUIApplicationOpenExternalURLOptionsKeyDictionary([:]), completionHandler: nil)
                } else {
                    UIApplication.shared.openURL(url)
                }
            }
        }
        alert.addAction(settingAction)
        UIApplication.shared.keyWindow?.rootViewController?.present(alert, animated: true, completion: nil)
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToUIApplicationOpenExternalURLOptionsKeyDictionary(_ input: [String: Any]) -> [UIApplication.OpenExternalURLOptionsKey: Any] {
    return Dictionary(uniqueKeysWithValues: input.map { key, value in (UIApplication.OpenExternalURLOptionsKey(rawValue: key), value)})
}
