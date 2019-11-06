// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import UIKit
//import AVFoundation

class QRScannerController: BaseViewController {
    var didScanStringsBlock: ((String) -> Void)?
    var cancelBlock: (() -> Void)?
    
    var sessionManager: AVCaptureSessionManager?
    lazy var scanView = ScanView()
    
    var scanAreaRect: CGRect {
        let boardLeft: CGFloat = 50.0
        let width = UIScreen.main.bounds.width
        let height = UIScreen.main.bounds.height
        let scanAreaWidth = width - CGFloat(boardLeft * 2.0)
        let scanAreaRect = CGRect(x: boardLeft, y: (height - scanAreaWidth) / 2.0 - 60, width: scanAreaWidth, height: scanAreaWidth)
        return scanAreaRect
    }
    
    let fromAddVC: Bool
    let messageService: MessageService
    init(fromAddVC: Bool = true, messageService: MessageService) {
        self.fromAddVC = fromAddVC
        self.messageService = messageService
        super.init()
        
        hidesBottomBarWhenPushed = true
        
        if self.fromAddVC == false {
            didScanStringsBlock = { [weak self] code in
                guard let self = self else { return }
                var vcs = self.navigationController?.viewControllers
                vcs?.removeLast()
                let vc = AddFriendViewController(messageService: self.messageService)
                vc.didScanHander(code)
                vcs?.append(vc)
                self.navigationController?.setViewControllers(vcs!, animated: true)
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = NSLocalizedString("QR Code", comment: "")
        
        let width = UIScreen.main.bounds.width
        let height = UIScreen.main.bounds.height
        let scanRect = CGRect(x: scanAreaRect.origin.y / height, y: scanAreaRect.origin.x / width, width: scanAreaRect.height / height, height: scanAreaRect.width / width)
        AVCaptureSessionManager.checkAuthorizationStatusForCamera(grant: {
            self.sessionManager = AVCaptureSessionManager(captureType: .AVCaptureTypeBoth, scanRect: scanRect, success: { [weak self] result in
                self?.didScan(result: result)
            })
            self.sessionManager?.showPreViewLayerIn(view: self.view)
            self.sessionManager?.isPlaySound = true
        }) {
            let action = UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: UIAlertAction.Style.default, handler: { (action) in
                let url = URL(string: UIApplication.openSettingsURLString)!
                UIApplication.shared.open(url, options: convertToUIApplicationOpenExternalURLOptionsKeyDictionary([:]), completionHandler: nil)
            })
            let con = UIAlertController(title: nil,
                                        message: NSLocalizedString("Please ensure camera permissions are granted for Tok. You can check by going to \"Settings -> Tok -> Camera\"", comment: ""),
                                        preferredStyle: .alert)
            con.addAction(action)
            self.present(con, animated: true, completion: nil)
        }
        
        let item = UIBarButtonItem(title: NSLocalizedString("Album", comment: ""), style: .plain, target: self, action: #selector(openPhotoLib))
        navigationItem.rightBarButtonItem = item
        
        setupViews()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        sessionManager?.start()
        
        scanView.startScanAnimation()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        sessionManager?.stop()
        
        scanView.stopScanAnimation()
    }
    
    func setupViews() {
        // ScanView
        let y = navigationController!.navigationBar.bounds.height + UIApplication.shared.statusBarFrame.height
        let scanViewDefaultFrame = CGRect(x: 0, y: 0, width: self.view.bounds.width, height: self.view.bounds.height - y)
        scanView.frame = scanViewDefaultFrame
        scanView.interestRect = scanAreaRect
        view.addSubview(scanView)
    }
    
    @objc func openPhotoLib() {
        AVCaptureSessionManager.checkAuthorizationStatusForPhotoLibrary(grant: {
            let imagePicker = UIImagePickerController()
            imagePicker.sourceType = UIImagePickerController.SourceType.photoLibrary
            imagePicker.delegate = self
            self.present(imagePicker, animated: true, completion: nil)
        }) {
            let action = UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: UIAlertAction.Style.default, handler: { (action) in
                let url = URL(string: UIApplication.openSettingsURLString)!
                UIApplication.shared.open(url, options: convertToUIApplicationOpenExternalURLOptionsKeyDictionary([:]), completionHandler: nil)
            })
            let con = UIAlertController(title: nil,
                                        message: NSLocalizedString("Please ensure photo permissions are granted for Tok. You can check by going to \"Settings -> Tok -> Photos\"", comment: ""),
                                        preferredStyle: .alert)
            con.addAction(action)
            self.present(con, animated: true, completion: nil)
        }
    }
    
    func didScan(result: String?) {
        guard let result = result else { return }
        
        didScanStringsBlock?(result)
        
        if fromAddVC {
            navigationController?.popViewController(animated: true)
        }
    }
}

extension QRScannerController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        sessionManager?.start()
        dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
// Local variable inserted by Swift 4.2 migrator.
let info = convertFromUIImagePickerControllerInfoKeyDictionary(info)

        dismiss(animated: true) {
            self.sessionManager?.start()
            self.sessionManager?.scanPhoto(image: info["UIImagePickerControllerOriginalImage"] as! UIImage, success: { [weak self] result in
                self?.didScan(result: result)
            })
        }
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
