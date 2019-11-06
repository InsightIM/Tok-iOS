//
//  PhotoPreviewViewController.swift
//  Tok
//
//  Created by Bryce on 2019/4/4.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import SnapKit

class PhotoPreviewViewController: UIViewController {
    
    var didSendImage: ((UIImage) -> Void)?
    
    private var backgroundImage: UIImage
    
    private var cancelConstraint: ConstraintMakerEditable!
    private var sendConstraint: ConstraintMakerEditable!
    
    init(image: UIImage) {
        self.backgroundImage = image
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    lazy var cancelButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(named: "GoBack"), for: UIControl.State())
        button.addTarget(self, action: #selector(cancelClick), for: .touchUpInside)
        return button
    }()
    
    lazy var sendButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(named: "Tick"), for: UIControl.State())
        button.addTarget(self, action: #selector(sendClick), for: .touchUpInside)
        return button
    }()
    
    var cancelView: UIView!
    var sendView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.gray
        let backgroundImageView = UIImageView(frame: view.frame)
        backgroundImageView.contentMode = UIView.ContentMode.scaleAspectFit
        backgroundImageView.image = backgroundImage
        view.addSubview(backgroundImageView)
        
        cancelView = cancelButton.setupBlurButton()
        sendView = sendButton.setupBlurButton()
        cancelView.alpha = 0
        sendView.alpha = 0
        
        view.addSubview(cancelView)
        cancelView.snp.makeConstraints { (make) in
            make.bottom.equalTo(self.view.safeArea.bottom).offset(-60)
            make.size.equalTo(80)
            make.centerX.equalToSuperview().multipliedBy(0.4)
        }
        
        view.addSubview(sendView)
        sendView.snp.makeConstraints { (make) in
            make.bottom.equalTo(self.view.safeArea.bottom).offset(-60)
            make.size.equalTo(80)
            make.centerX.equalToSuperview().multipliedBy(1.6)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        UIView.animate(withDuration: 0.25) {
            self.cancelView.alpha = 1
            self.sendView.alpha = 1
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    @objc func sendClick() {
        didSendImage?(backgroundImage)
        dismiss(animated: false, completion: nil)
    }
    
    @objc func cancelClick() {
        dismiss(animated: false, completion: nil)
    }
}

extension UIButton {
    func setupBlurButton() -> UIView {
        let blur = UIBlurEffect(style: UIBlurEffect.Style.light)
        let blurView = UIVisualEffectView(effect: blur)
        blurView.layer.cornerRadius = 40
        blurView.layer.masksToBounds = true
        blurView.contentView.addSubview(self)
        self.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        return blurView
    }
}
