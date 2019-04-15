//
//  CameraViewController.swift
//  Tok
//
//  Created by Bryce on 2019/4/3.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import SwiftyCam

class CameraViewController: SwiftyCamViewController {
    
    var didSendFile: ((URL) -> Void)?
    var didSendImage: ((UIImage) -> Void)?
    
    lazy var captureButton = SwiftyRecordButton()
    
    lazy var flipCameraButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(named: "CameraSwitch"), for: .normal)
        button.addTarget(self, action: #selector(CameraViewController.cameraSwitchTapped(_:)), for: .touchUpInside)
        return button
    }()
    
    lazy var flashButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(named: "FlashAuto"), for: .normal)
        button.addTarget(self, action: #selector(CameraViewController.toggleFlashTapped(_:)), for: .touchUpInside)
        return button
    }()
    
    lazy var cancelButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(named: "DownArrow"), for: .normal)
        button.addTarget(self, action: #selector(CameraViewController.cancelClick), for: .touchUpInside)
        return button
    }()

    override func viewDidLoad() {
        videoGravity = .resizeAspectFill
        videoQuality = .resolution1280x720
        
        super.viewDidLoad()
        
        shouldPrompToAppSettings = true
        cameraDelegate = self
        maximumVideoDuration = 10.0
        shouldUseDeviceOrientation = true
        allowAutoRotate = true
        audioEnabled = true
        flashMode = .auto
        
        view.addSubview(captureButton)
        captureButton.snp.makeConstraints { (make) in
            make.centerX.equalToSuperview()
            make.size.equalTo(75)
            make.bottom.equalTo(self.view.safeArea.bottom).offset(-60)
        }
        
        view.addSubview(cancelButton)
        cancelButton.snp.makeConstraints { (make) in
            make.centerY.equalTo(captureButton)
            make.size.equalTo(60)
            make.centerX.equalToSuperview().multipliedBy(0.4)
        }
        
        view.addSubview(flipCameraButton)
        flipCameraButton.snp.makeConstraints { (make) in
            make.size.equalTo(CGSize(width: 30, height: 23))
            make.top.equalTo(self.view.safeArea.top).offset(20)
            make.right.equalTo(-20)
        }
        
        view.addSubview(flashButton)
        flashButton.snp.makeConstraints { (make) in
            make.size.equalTo(35)
            make.centerY.equalTo(flipCameraButton)
            make.left.equalTo(20)
        }
        
        addBlurView()
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        captureButton.delegate = self
    }
    
    @objc
    func cameraSwitchTapped(_ sender: Any) {
        switchCamera()
    }
    
    @objc
    func toggleFlashTapped(_ sender: Any) {
        //flashEnabled = !flashEnabled
        toggleFlashAnimation()
    }
    
    @objc
    func cancelClick() {
        dismiss(animated: true, completion: nil)
    }
}

extension CameraViewController: SwiftyCamViewControllerDelegate {
    
    func swiftyCamSessionDidStartRunning(_ swiftyCam: SwiftyCamViewController) {
        print("Session did start running")
        removeBlurView()
        captureButton.buttonEnabled = true
    }
    
    func swiftyCamSessionDidStopRunning(_ swiftyCam: SwiftyCamViewController) {
        print("Session did stop running")
        removeBlurView()
        captureButton.buttonEnabled = false
    }
    
    func swiftyCam(_ swiftyCam: SwiftyCamViewController, didTake photo: UIImage) {
        let newVC = PhotoPreviewViewController(image: photo)
        newVC.didSendImage = didSendImage
        present(newVC, animated: false, completion: nil)
    }
    
    func swiftyCam(_ swiftyCam: SwiftyCamViewController, didBeginRecordingVideo camera: SwiftyCamViewController.CameraSelection) {
        print("Did Begin Recording")
        captureButton.growButton()
        hideButtons()
    }
    
    func swiftyCam(_ swiftyCam: SwiftyCamViewController, didFinishRecordingVideo camera: SwiftyCamViewController.CameraSelection) {
        print("Did finish Recording")
        captureButton.shrinkButton()
        showButtons()
    }
    
    func swiftyCam(_ swiftyCam: SwiftyCamViewController, didFinishProcessVideoAt url: URL) {
        let newVC = VideoPreviewViewController(videoURL: url)
        newVC.didSendFile = didSendFile
        present(newVC, animated: true, completion: nil)
    }
    
    func swiftyCam(_ swiftyCam: SwiftyCamViewController, didFocusAtPoint point: CGPoint) {
        print("Did focus at point: \(point)")
        focusAnimationAt(point)
    }
    
    func swiftyCamDidFailToConfigure(_ swiftyCam: SwiftyCamViewController) {
        let message = NSLocalizedString("Unable to capture media", comment: "Alert message when something goes wrong during capture session configuration")
        let alertController = UIAlertController(title: "Tok", message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"), style: .cancel, handler: nil))
        present(alertController, animated: true, completion: nil)
    }
    
    func swiftyCam(_ swiftyCam: SwiftyCamViewController, didChangeZoomLevel zoom: CGFloat) {
        print("Zoom level did change. Level: \(zoom)")
        print(zoom)
    }
    
    func swiftyCam(_ swiftyCam: SwiftyCamViewController, didSwitchCameras camera: SwiftyCamViewController.CameraSelection) {
        print("Camera did change to \(camera.rawValue)")
        print(camera)
    }
    
    func swiftyCam(_ swiftyCam: SwiftyCamViewController, didFailToRecordVideo error: Error) {
        print(error)
    }
}

fileprivate extension CameraViewController {
    
    func addBlurView() {
        if let screenSnapshot = self.view.screenshot(),
            let image = screenSnapshot.blurryImage(withOptions: BlurryOptions.pro, overlayColor: nil, blurRadius: 10) {
            let imageView = UIImageView(frame: UIScreen.main.bounds)
            imageView.contentMode = .scaleAspectFill
            imageView.image = image
            imageView.tag = 1000111
            view.addSubview(imageView)
        }
    }
    
    func removeBlurView() {
        let blurImageView = view.viewWithTag(1000111)
        blurImageView?.removeFromSuperview()
    }
    
    func hideButtons() {
        UIView.animate(withDuration: 0.25) {
            self.flashButton.alpha = 0.0
            self.flipCameraButton.alpha = 0.0
            self.cancelButton.alpha = 0.0
        }
    }
    
    func showButtons() {
        UIView.animate(withDuration: 0.25) {
            self.flashButton.alpha = 1.0
            self.flipCameraButton.alpha = 1.0
            self.cancelButton.alpha = 1.0
        }
    }
    
    func focusAnimationAt(_ point: CGPoint) {
        let focusView = UIImageView(image: UIImage(named: "Focus"))
        focusView.center = point
        focusView.alpha = 0.0
        view.addSubview(focusView)
        
        UIView.animate(withDuration: 0.25, delay: 0.0, options: .curveEaseInOut, animations: {
            focusView.alpha = 1.0
            focusView.transform = CGAffineTransform(scaleX: 1.25, y: 1.25)
        }) { (success) in
            UIView.animate(withDuration: 0.15, delay: 0.5, options: .curveEaseInOut, animations: {
                focusView.alpha = 0.0
                focusView.transform = CGAffineTransform(translationX: 0.6, y: 0.6)
            }) { (success) in
                focusView.removeFromSuperview()
            }
        }
    }
    
    func toggleFlashAnimation() {
        //flashEnabled = !flashEnabled
        if flashMode == .auto {
            flashMode = .on
            flashButton.setImage(UIImage(named: "Flash"), for: UIControl.State())
        } else if flashMode == .on {
            flashMode = .off
            flashButton.setImage(UIImage(named: "FlashOutline"), for: UIControl.State())
        } else if flashMode == .off {
            flashMode = .auto
            flashButton.setImage(UIImage(named: "FlashAuto"), for: UIControl.State())
        }
    }
}
