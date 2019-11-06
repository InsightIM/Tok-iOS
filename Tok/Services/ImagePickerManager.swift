//
//  ImagePickerManager.swift
//  Tok
//
//  Created by Bryce on 2018/7/8.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit
import Photos

typealias ImagePickerManagerDidFinishPickingPhotosHandler = (UIImage) -> ()

class ImagePickerManager: NSObject {
    
    var didFinishPickingPhotosHandler: ImagePickerManagerDidFinishPickingPhotosHandler?
    
    weak var viewController: UIViewController?
    var imagePickerController: UIImagePickerController?
    
    static var shared : ImagePickerManager = {
        let shared = ImagePickerManager()
        return shared
    }()
    
    func showAction(onViewController: UIViewController, didFinishPickingPhotosHandler: @escaping ImagePickerManagerDidFinishPickingPhotosHandler) {
        self.viewController = onViewController
        self.didFinishPickingPhotosHandler = didFinishPickingPhotosHandler
        
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: nil)
        
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            let cameraAction = UIAlertAction(title: NSLocalizedString("Take a picture", comment: ""), style: .default, handler: { (_) in
                if !self.cameraIsAuthorized() {
                    return
                }
                self.presentImagePicker(onViewController: onViewController, sourceType: .camera)
            })
            alert.addAction(cameraAction)
        }
        
        let photoAction = UIAlertAction(title: NSLocalizedString("Choose photo", comment: ""), style: .default) { (_) in
            if !self.photoIsAuthorized() {
                return
            }
            self.presentImagePicker(onViewController: onViewController, sourceType: .savedPhotosAlbum)
        }
        alert.addAction(photoAction)
        alert.addAction(cancelAction)
        viewController?.present(alert, animated: true, completion: nil)
        
    }
    
    private func cameraIsAuthorized() -> Bool {
        let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
        switch authStatus {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { (granted) in
                if granted {
                    DispatchQueue.main.async {
                        if let viewController = self.viewController{
                            self.presentImagePicker(onViewController: viewController, sourceType: .camera)
                        }
                    }
                }
            })
            break
        case .denied, .restricted:
            self.requireCameraAuthorization()
            break
        default:
            break
        }
        return authStatus == .authorized
    }
    
    private func photoIsAuthorized() -> Bool {
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
        case .notDetermined:
            // 当某些情况下AuthorizationStatus == AuthorizationStatusNotDetermined时，无法弹出系统首次使用的授权alertView，系统应用设置里亦没有相册的设置，此时将无法使用，故作以下操作，弹出系统首次使用的授权alertView
            DispatchQueue.global(qos: .default).async {
                PHPhotoLibrary.requestAuthorization({ (status) in
                    if status == .authorized {
                        DispatchQueue.main.async {
                            self.presentImagePicker(onViewController: self.viewController!, sourceType: .savedPhotosAlbum)
                        }
                    }
                })
            }
            break
        case .denied, .restricted:
            requirePhotoAuthorization()
            break
        default:
            break
        }
        return status == .authorized
    }
    
    private func presentImagePicker(onViewController: UIViewController, sourceType: UIImagePickerController.SourceType) {
        let imagePickerController = UIImagePickerController()
        imagePickerController.delegate = self
        imagePickerController.sourceType = sourceType
        imagePickerController.allowsEditing = true
        self.imagePickerController = imagePickerController
        onViewController.present(imagePickerController, animated: true, completion: nil)
    }
    
    private func requirePhotoAuthorization() {
        showAlert(message: NSLocalizedString("Please ensure photo permissions are granted for Tok. You can check by going to \"Settings -> Privacy -> Photos\"", comment: ""))
    }
    
    func requireCameraAuthorization() {
        showAlert(message: NSLocalizedString("Please ensure camera permissions are granted for Tok. You can check by going to \"Settings -> Privacy -> Camera\"", comment: ""))
    }
    
    func showAlert(message: String) {
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

extension ImagePickerManager: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
// Local variable inserted by Swift 4.2 migrator.
let info = convertFromUIImagePickerControllerInfoKeyDictionary(info)

        if let image = info[convertFromUIImagePickerControllerInfoKey(UIImagePickerController.InfoKey.originalImage)] as? UIImage {
            if didFinishPickingPhotosHandler != nil {
                didFinishPickingPhotosHandler!(image)
                didFinishPickingPhotosHandler = nil
            }
        }
        picker.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
        didFinishPickingPhotosHandler = nil
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKeyDictionary(_ input: [UIImagePickerController.InfoKey: Any]) -> [String: Any] {
	return Dictionary(uniqueKeysWithValues: input.map {key, value in (key.rawValue, value)})
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToUIApplicationOpenExternalURLOptionsKeyDictionary(_ input: [String: Any]) -> [UIApplication.OpenExternalURLOptionsKey: Any] {
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (UIApplication.OpenExternalURLOptionsKey(rawValue: key), value)})
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKey(_ input: UIImagePickerController.InfoKey) -> String {
	return input.rawValue
}
