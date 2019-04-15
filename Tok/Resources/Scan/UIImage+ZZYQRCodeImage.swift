//
//  UIImage+ZZYQRCodeImage.swift
//  ZZYQRCodeSwift
//
//  Created by 张泽宇 on 2017/5/22.
//  Copyright © 2017年 zzy. All rights reserved.
//

import Foundation
import UIKit
import CoreImage

extension UIImage {
    
    enum QRCodeImageType {
        case CircularImage
        case SquareImage
    }
    
    class func createQRCode(size: CGFloat, dataStr: String) -> UIImage? {

        let filter = CIFilter(name: "CIQRCodeGenerator")
        filter?.setDefaults()
        
        let data = dataStr.data(using: .utf8)
        filter?.setValue(data, forKey: "inputMessage")
        guard let cIImage = filter?.outputImage else {
            return nil
        }
        return self .createNonInterpolatedUIImage(image: cIImage, size: size)
    }
    
    class func createCustomizeQRCode(size: CGFloat,
                                     dataStr: String,
                                     imageType: QRCodeImageType,
                                     iconImage: UIImage,
                                     iconImageSize: CGFloat) -> UIImage? {
        guard let bgImage = UIImage.createQRCode(size: size, dataStr: dataStr) else {
            return nil
        }
        var tempImage: UIImage? = iconImage
        if imageType == .CircularImage {
            tempImage = UIImage.createCircularImage(image: iconImage)
        }
        var result :UIImage?
        if let t = tempImage {
            result = UIImage.createNewImage(bgImage: bgImage, iconImage: t, iconSize: iconImageSize)
        }
        return result
    }
    
    class func addQRCodeBg(bgImage: UIImage, bgImageSize:CGFloat, QRImage: UIImage) -> UIImage? {
        let tempImage = UIImage.imageCompress(sourceImage: bgImage, size: CGSize(width: bgImageSize, height: bgImageSize))
        return  UIImage.createNewImage(bgImage: tempImage!, iconImage: QRImage, iconSize: QRImage.size.width)
    }
    
    private class func createNewImage(bgImage: UIImage, iconImage:UIImage, iconSize:CGFloat) -> UIImage? {
        UIGraphicsBeginImageContext(bgImage.size)
        bgImage.draw(in: CGRect(x: 0, y: 0, width: bgImage.size.width, height: bgImage.size.height))
        let imageX: CGFloat = (bgImage.size.width - iconSize) * 0.5
        let imageY: CGFloat = (bgImage.size.height - iconSize) * 0.5
        iconImage.draw(in: CGRect(x: imageX, y: imageY, width: iconSize, height: iconSize))
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result
    }
    
    private class func createCircularImage(image: UIImage) -> UIImage?{
        UIGraphicsBeginImageContextWithOptions(image.size, false, 0)
        let ctx = UIGraphicsGetCurrentContext()
        ctx?.addEllipse(in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
        ctx?.clip()
        image.draw(in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result
    }
    
    private class func createNonInterpolatedUIImage(image: CIImage, size: CGFloat) -> UIImage? {
        let extent = image.extent.integral
        let scale = min(size/extent.width, size/extent.height)
        let width = extent.width * scale
        let height = extent.height * scale
        let cs = CGColorSpaceCreateDeviceGray()
        
        let context = CIContext(options: nil);
        let bitmapImage = context.createCGImage(image, from: extent)
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        guard let bitmapRef = CGContext(data: nil,
                                        width: Int(width),
                                        height: Int(height),
                                        bitsPerComponent: 8,
                                        bytesPerRow: 0,
                                        space: cs,
                                        bitmapInfo: bitmapInfo.rawValue)else {
                                            return nil;
        }
    
        bitmapRef.interpolationQuality = CGInterpolationQuality.none
        bitmapRef.scaleBy(x: scale,y: scale)
        bitmapRef.draw(bitmapImage!, in: extent)
        
        guard let scaledImage = bitmapRef.makeImage() else {
            return nil;
        }
        
        return UIImage(cgImage: scaledImage)
    }
    
    private class func imageCompress(sourceImage: UIImage, size:CGSize) -> UIImage? {
        let imageSize = sourceImage.size
        let width = imageSize.width
        let height = imageSize.height
        let targetWidth = size.width
        let targetHeight = size.height
        var scaleFactor:CGFloat = 0
        var scaledWidth = targetWidth
        var scaledHeight = targetHeight
        var thumbnailPoint = CGPoint(x: 0, y: 0)
        if !__CGSizeEqualToSize(imageSize, size) {
            let widthFactor:CGFloat = CGFloat(targetWidth / width)
            let heightFactor:CGFloat = CGFloat(targetHeight / height)
            
            if(widthFactor > heightFactor){
                scaleFactor = widthFactor
                
            }
            else{
                
                scaleFactor = heightFactor
            }
            scaledWidth = width * scaleFactor
            scaledHeight = height * scaleFactor
            
            if(widthFactor > heightFactor){
                
                thumbnailPoint.y = (targetHeight - scaledHeight) * 0.5;
            }else if(widthFactor < heightFactor){
                
                thumbnailPoint.x = (targetWidth - scaledWidth) * 0.5;
            }
        }
        
        UIGraphicsBeginImageContext(size)
        
        let thumbnailRect = CGRect(origin: thumbnailPoint, size: CGSize(width: scaledWidth, height: scaledHeight))
        
        sourceImage.draw(in: thumbnailRect)
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result
    }

}
