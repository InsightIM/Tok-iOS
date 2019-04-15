//
//  ProfilePhotoViewController.swift
//  Tok
//
//  Created by Bryce on 2018/11/14.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit
import HXPhotoPicker
import RSKImageCropper

class ProfilePhotoViewController: BaseViewController {

    let image: UIImage?
    var imageScrollView = ImageScrollView()
    
    lazy var photoPicker: HXPhotoManager = {
        let manager = HXPhotoManager(type: .photo)!
        manager.configuration.openCamera = true
        manager.configuration.lookLivePhoto = true
        manager.configuration.photoMaxNum = 1
        manager.configuration.maxNum = 1
        manager.configuration.saveSystemAblum = false
        manager.configuration.showDateSectionHeader = false
        manager.configuration.hideOriginalBtn = true
        manager.configuration.photoCanEdit = true
        return manager
    }()
    
    init(image: UIImage?) {
        self.image = image
        
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = NSLocalizedString("Photo", comment: "")
        view.backgroundColor = .black
        
        imageScrollView.imageContentMode = .aspectFit
        imageScrollView.centerYOffset = 44
        view.addSubview(imageScrollView)
        imageScrollView.snp.makeConstraints { (make) in
            make.left.right.equalToSuperview()
            make.top.equalTo(self.view.safeArea.top)
            make.bottom.equalTo(self.view.safeArea.bottom)
        }
        
        view.layoutIfNeeded()
        if let image = image {
            imageScrollView.display(image: image)
        }
        
        let edit = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(ProfilePhotoViewController.didEdit))
        navigationItem.rightBarButtonItem = edit
    }
    
    @objc func didEdit() {
        let chooseAction: AlertViewManager.Action = { [weak self] in
            self?.photoPicker.clearSelectedList()
            self?.hx_presentSelectPhotoController(with: self?.photoPicker, didDone: { (_, photoList, _, _, _, manager) in
                guard let photoList = photoList else { return }
                (photoList as NSArray).hx_requestImage(withOriginal: false, completion: { (imageList, _) in
                    guard let image = imageList?.first else {
                        return
                    }
                    
                    let vc = RSKImageCropViewController(image: image, cropMode: RSKImageCropMode.square)
                    vc.delegate = self
                    self?.navigationController?.pushViewController(vc, animated: false)
                })
            }, cancel: { (_, manager) in
                manager?.clearSelectedList()
            })
        }
        
        let deleteAction: AlertViewManager.Action = { [weak self] in
            do {
                let data = Data()
                try UserService.shared.toxMananger!.user.setUserAvatar(data)
                
                self?.navigationController?.popViewController(animated: true)
            }
            catch let error as NSError {
                ProgressHUD.showTextHUD(withText: error.localizedDescription, in: self?.view)
            }
        }
        AlertViewManager.showActionSheet(with: [
            (NSLocalizedString("Choose Photo", comment: ""), .default, chooseAction),
            (NSLocalizedString("Remove Photo", comment: ""), .destructive, deleteAction)
            ])
    }
}

extension ProfilePhotoViewController: RSKImageCropViewControllerDelegate {
    
    func imageCropViewControllerDidCancelCrop(_ controller: RSKImageCropViewController) {
        self.navigationController?.popViewController(animated: true)
    }
    
    func imageCropViewController(_ controller: RSKImageCropViewController, didCropImage croppedImage: UIImage, usingCropRect cropRect: CGRect, rotationAngle: CGFloat) {
        do {
            let data = try MeViewController.pngDataFromImage(croppedImage)
            try UserService.shared.toxMananger!.user.setUserAvatar(data)
            
            self.imageScrollView.display(image: croppedImage)
        }
        catch let error as NSError {
            ProgressHUD.showTextHUD(withText: error.localizedDescription, in: self.view)
        }
        self.navigationController?.popViewController(animated: true)
    }
}
