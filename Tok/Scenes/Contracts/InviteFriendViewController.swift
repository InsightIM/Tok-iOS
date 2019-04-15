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

let officalLink = "https://www.tok.life"

class InviteFriendViewController: BaseViewController {
    
    private let disposeBag = DisposeBag()

    lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 16
        view.layer.masksToBounds = true
        view.layer.shadowColor = UIColor.black.withAlphaComponent(0.3).cgColor
        return view
    }()
    
    lazy var avatarImageView: AvatarImageView = AvatarImageView()
    
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
        label.font = UIFont.systemFont(ofSize: 11)
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
    
    lazy var shareTextLabel: UILabel = {
        let label = UILabel()
        label.copyable = true
        label.textColor = UIColor.tokFootnote
        label.font = UIFont.systemFont(ofSize: 12)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.text = String(format: NSLocalizedString("Peer-to-peer encrypted chat, I’m in Tok, click %@, free download Tok app. If you installed it, please copy this text $%@$, open Tok can add me as friends.", comment: ""), officalLink, UserService.shared.toxMananger!.user.userAddress)
        return label
    }()
    
    private var shareTextButton: UIButton = {
        let button = UIButton()
        button.setBackgroundImage(UIImage(named: "ButtonInvite"), for: .normal)
        button.setTitle(NSLocalizedString("Share by Text", comment: ""), for: .normal)
        button.setTitleColor(.lightGray, for: .highlighted)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        return button
    }()
    
    private var shareImageButton: UIButton = {
        let button = UIButton()
        button.setBackgroundImage(UIImage(named: "ButtonInvite"), for: .normal)
        button.setTitle(NSLocalizedString("Share by Image", comment: ""), for: .normal)
        button.setTitleColor(.lightGray, for: .highlighted)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        return button
    }()
    
    private lazy var backButton: UIButton = {
        let backButton = UIButton(type: .system)
        backButton.tintColor = .white
        backButton.setImage(UIImage(named: "NavbarBack"), for: .normal)
        return backButton
    }()
    
    private lazy var lineView = UIView()
    
    lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        return scrollView
    }()
    
    override init() {
        super.init()
        
        hidesBottomBarWhenPushed = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let bgView = UIImageView()
        bgView.image = UIImage(named: "LaunchBg")
        bgView.contentMode = .scaleAspectFill
        view.addSubview(bgView)
        bgView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { (make) in
            make.left.equalTo(40)
            make.right.equalTo(-40)
            make.top.equalTo(self.view.safeArea.top).offset(40)
        }
        
        scrollView.addSubview(containerView)
        containerView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
            make.width.equalToSuperview()
        }
        
        view.addSubview(backButton)
        backButton.snp.makeConstraints { (make) in
            make.size.equalTo(40)
            make.left.equalTo(0)
            make.top.equalTo(self.view.safeArea.top)
        }
        
        backButton.rx.tap
            .subscribe(onNext: { [unowned self] _ in
                self.dismiss(animated: true, completion: nil)
            })
            .disposed(by: disposeBag)
        
        avatarImageView.cornerRadius = 25
        containerView.addSubview(avatarImageView)
        avatarImageView.snp.makeConstraints { (make) in
            make.size.equalTo(50)
            make.centerX.equalToSuperview()
            make.top.equalTo(50)
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
            make.top.equalTo(descriptionLabel.snp.bottom).offset(50)
            make.size.equalTo(110)
        }
        
        containerView.addSubview(qrcodeTipLabel)
        qrcodeTipLabel.snp.makeConstraints { (make) in
            make.top.equalTo(qrcodeImageView.snp.bottom).offset(8)
            make.centerX.equalToSuperview()
            make.left.greaterThanOrEqualTo(20)
            make.right.lessThanOrEqualTo(-20)
        }
        
        containerView.addSubview(shareTextLabel)
        shareTextLabel.snp.makeConstraints { (make) in
            make.top.equalTo(qrcodeImageView.snp.bottom).offset(64)
            make.left.equalTo(10)
            make.right.equalTo(-10)
            make.bottom.equalTo(-36)
        }
        
        view.addSubview(shareTextButton)
        view.addSubview(shareImageButton)
        
        shareTextButton.snp.makeConstraints { (make) in
            make.left.equalTo(20)
            make.top.equalTo(scrollView.snp.bottom).offset(20)
            make.bottom.equalTo(self.view.safeArea.bottom).offset(-20)
            make.height.equalTo(50)
        }
        
        shareImageButton.snp.makeConstraints { (make) in
            make.left.equalTo(shareTextButton.snp.right).offset(15)
            make.right.equalTo(-20)
            make.bottom.equalTo(shareTextButton)
            make.height.equalTo(50)
            make.width.equalTo(shareTextButton)
        }
        
        containerView.snp.updateConstraints { (make) in
            make.bottom.equalToSuperview()
        }
        
        avatarImageView.setImage(with: UserService.shared.avatarData, identityNumber: 0, name: UserService.shared.nickName)
        
        descriptionLabel.text = String(format: NSLocalizedString("Hello，I'm %@\nI'm in Tok，peer-to-peer encrypted chat!", comment: ""), UserService.shared.nickName ?? "Tok")
        
        let qrtext = "\(officalLink)?toxid=\(UserService.shared.toxMananger!.user.userAddress)"
        qrcodeImageView.image = qrImageFromText(text: qrtext)
        
        containerView.addSubview(lineView)
        lineView.snp.makeConstraints { (make) in
            make.top.equalTo(shareTextLabel.snp.top).offset(-10)
            make.left.equalTo(-10)
            make.right.equalTo(10)
            make.bottom.equalTo(10)
        }
        
        view.layoutIfNeeded()
        lineView.addDashedBorder()
        
        shareTextButton.rx.tap
            .subscribe(onNext: { [unowned self] _ in
                guard let text = self.shareTextLabel.text else {
                    return
                }
                
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
        let view = UIView(frame: CGRect(0, 0, UIScreen.main.bounds.width, UIScreen.main.bounds.height * 2))
        
        let contentView = UIView()
        view.addSubview(contentView)
        contentView.snp.makeConstraints { (make) in
            make.top.equalToSuperview()
            make.left.right.equalToSuperview()
            make.bottom.lessThanOrEqualToSuperview()
        }
        
        let containerView: UIView = {
            let view = UIView()
            view.backgroundColor = .white
            view.layer.cornerRadius = 16
            view.layer.masksToBounds = true
            view.layer.shadowColor = UIColor.black.withAlphaComponent(0.3).cgColor
            return view
        }()
        
        let avatarImageView: AvatarImageView = AvatarImageView()
        
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
            label.copyable = true
            label.textColor = UIColor.tokFootnote
            label.font = UIFont.systemFont(ofSize: 14)
            label.textAlignment = .center
            label.numberOfLines = 0
            label.text = NSLocalizedString("Long press this picture a minute, extract the QR code, download the app\n Open Tok and scan this QR code, add me as a friend", comment: "")
            return label
        }()
        
        let sloganLabel: UILabel = {
            let label = UILabel()
            label.textColor = UIColor.white
            label.font = UIFont.systemFont(ofSize: 12)
            label.textAlignment = .center
            label.text = NSLocalizedString("Tok, Make the world connect freely!", comment: "")
            label.adjustsFontSizeToFitWidth = true
            return label
        }()
        
        contentView.addSubview(containerView)
        containerView.snp.makeConstraints { (make) in
            make.left.equalTo(40)
            make.right.equalTo(-40)
            make.centerX.equalToSuperview()
            make.top.equalTo(40)
        }
        
        avatarImageView.cornerRadius = 25
        avatarImageView.setImage(with: UserService.shared.avatarData, identityNumber: 0, name: UserService.shared.nickName)
        containerView.addSubview(avatarImageView)
        avatarImageView.snp.makeConstraints { (make) in
            make.size.equalTo(50)
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
            make.size.equalTo(110)
        }
        
        containerView.addSubview(shareTextLabel)
        shareTextLabel.snp.makeConstraints { (make) in
            make.top.equalTo(qrcodeImageView.snp.bottom).offset(50)
            make.left.equalTo(10)
            make.right.equalTo(-10)
            make.bottom.equalTo(-36)
        }
        
        contentView.addSubview(sloganLabel)
        sloganLabel.snp.makeConstraints { (make) in
            make.top.equalTo(containerView.snp.bottom).offset(40)
            make.centerX.equalToSuperview()
            make.bottom.equalTo(-40)
        }
        
        contentView.layoutIfNeeded()
        
        let bgView = UIImageView()
        bgView.frame = contentView.bounds
        bgView.image = UIImage(named: "LaunchBg")
        bgView.contentMode = .scaleAspectFill
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
