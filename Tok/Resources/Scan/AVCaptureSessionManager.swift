import UIKit
import AVFoundation
import Photos

typealias SuccessBlock = (String?) -> Void
typealias GrantBlock = () -> ()
typealias DeniedBlock = () -> ()

class AVCaptureSessionManager: AVCaptureSession, AVCaptureMetadataOutputObjectsDelegate {
    
    var soundName:String?
    
    var isPlaySound = false
    
    private var block: SuccessBlock?
    
    private lazy var device: AVCaptureDevice? = {
        return AVCaptureDevice.default(for:.video)
    }()
    
    private lazy var preViewLayer: AVCaptureVideoPreviewLayer = {
        return AVCaptureVideoPreviewLayer(session: self)
    }()
    
    private var output: AVCaptureMetadataOutput?
    private var scanRect: CGRect = CGRect.null
    
    convenience init(captureType: AVCaptureType,
                     scanRect: CGRect,
                     success: @escaping SuccessBlock) {
        self.init()
        block = success
        
        var input: AVCaptureDeviceInput?
        do {
            if let device = device {
                input = try AVCaptureDeviceInput(device: device)
            }
        } catch let error as NSError {
            print("AVCaputreDeviceError \(error)")
        }
        
        let output = AVCaptureMetadataOutput()
        output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        
        if !scanRect.equalTo(CGRect.null) {
            output.rectOfInterest = scanRect
        }
        
        sessionPreset = AVCaptureSession.Preset.high
        if let input = input {
            if canAddInput(input) {
                addInput(input)
            }
            
        }
        
        if canAddOutput(output) {
            addOutput(output)
        }
        
        output.metadataObjectTypes = captureType.supportTypes()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(stop),
                                               name: UIApplication.didEnterBackgroundNotification,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(start),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)
        
    }
    
    class func createSessionManager(captureType: AVCaptureType,
                                    scanRect: CGRect,
                                    success: @escaping SuccessBlock) ->AVCaptureSessionManager {
        let result = AVCaptureSessionManager(captureType: captureType, scanRect: scanRect, success: success);
        return result
    }
    
    class func checkAuthorizationStatusForCamera(grant:@escaping GrantBlock, denied:DeniedBlock) {
        let session = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back)
        if session.devices.count > 0 {
            let status = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
            switch status {
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: { (granted) in
                    if granted {
                        DispatchQueue.main.async(execute: {
                            grant()
                        })
                    }
                })
            case .authorized:
                grant()
            case .denied:
                denied()
            default:
                break
            }
        }
    }
    
    class func checkAuthorizationStatusForPhotoLibrary(grant:@escaping GrantBlock, denied:DeniedBlock) {
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization({ (status) in
                if status == PHAuthorizationStatus.authorized {
                    DispatchQueue.main.async(execute: {
                        grant()
                    })
                }
            })
            
        case .authorized:
            grant()
        case .denied:
            denied()
        default:
            break
        }
    }
    
    func scanPhoto(image: UIImage, success: SuccessBlock) {
        let detector = CIDetector(ofType: CIDetectorTypeQRCode,
                                  context: nil,
                                  options: [CIDetectorAccuracy : CIDetectorAccuracyHigh])
        if let detector = detector, let cgImage = image.cgImage {
            let features = detector.features(in: CIImage(cgImage: cgImage))
            for temp in features {
                let result = (temp as! CIQRCodeFeature).messageString
                success(result)
                return
            }
            success(nil)
        }else {
            success(nil)
        }
        
    }
    
    func showPreViewLayerIn(view :UIView) {
        preViewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        preViewLayer.frame = view.bounds
        view.layer.insertSublayer(preViewLayer, at: 0)
        start()
    }
    
    func turnTorch(state:Bool) {
        if let device = device {
            if (device.hasTorch) {
                do {
                    try device.lockForConfiguration()
                } catch let error as NSError {
                    print("TorchError  \(error)")
                }
                if (state) {
                    device.torchMode = AVCaptureDevice.TorchMode.on
                } else {
                    device.torchMode = AVCaptureDevice.TorchMode.off
                }
                device.unlockForConfiguration()
            }
        }
    }
    
    func playSound() {
        if isPlaySound {
            var result = "sound.caf"
            if let temp = soundName, temp != ""{
                result = temp
            }
            
            if let urlstr = Bundle.main.path(forResource: result, ofType: nil) {
                let fileURL = NSURL(fileURLWithPath: urlstr)
                var soundID:SystemSoundID = 0;
                AudioServicesCreateSystemSoundID(fileURL, &soundID)
                AudioServicesPlaySystemSound(soundID)
            }
        }
    }
    
    @objc func start() {
        startRunning()
    }
    
    @objc func stop() {
        stopRunning()
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if (metadataObjects.count > 0) {
            stop()
            playSound()
            
            let result = metadataObjects.last as! AVMetadataMachineReadableCodeObject
            block!(result.stringValue)
        }
    }
}

enum AVCaptureType {
    case AVCaptureTypeQRCode
    case AVCaptureTypeBarCode
    case AVCaptureTypeBoth
    func supportTypes() -> [AVMetadataObject.ObjectType] {
        switch self {
        case .AVCaptureTypeQRCode:
            return [AVMetadataObject.ObjectType.qr]
        case .AVCaptureTypeBarCode:
            return [AVMetadataObject.ObjectType.dataMatrix,
                    AVMetadataObject.ObjectType.itf14,
                    AVMetadataObject.ObjectType.interleaved2of5,
                    AVMetadataObject.ObjectType.aztec,
                    AVMetadataObject.ObjectType.pdf417,
                    AVMetadataObject.ObjectType.code128,
                    AVMetadataObject.ObjectType.code93,
                    AVMetadataObject.ObjectType.ean8,
                    AVMetadataObject.ObjectType.ean13,
                    AVMetadataObject.ObjectType.code39Mod43,
                    AVMetadataObject.ObjectType.code39,
                    AVMetadataObject.ObjectType.upce]
        case .AVCaptureTypeBoth:
            return [AVMetadataObject.ObjectType.qr,
                    AVMetadataObject.ObjectType.dataMatrix,
                    AVMetadataObject.ObjectType.itf14,
                    AVMetadataObject.ObjectType.interleaved2of5,
                    AVMetadataObject.ObjectType.aztec,
                    AVMetadataObject.ObjectType.pdf417,
                    AVMetadataObject.ObjectType.code128,
                    AVMetadataObject.ObjectType.code93,
                    AVMetadataObject.ObjectType.ean8,
                    AVMetadataObject.ObjectType.ean13,
                    AVMetadataObject.ObjectType.code39Mod43,
                    AVMetadataObject.ObjectType.code39,
                    AVMetadataObject.ObjectType.upce]
        }
    }
}
