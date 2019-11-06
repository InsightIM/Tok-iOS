//
//  ScanView.swift
//  Tok
//
//  Created by Bryce on 2017/9/20.
//  Copyright © 2017年 Insight. All rights reserved.
//

import UIKit

class ScanView: UIView {
    
    var interestRect: CGRect = CGRect.zero
    
    let scanMargin: CGFloat = 6

    private lazy var borderImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "ScanBorder")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private lazy var lineLayer: CALayer = {
        let layer = CALayer()
        let image = UIImage(named: "ScanLine")
        layer.contents = image?.cgImage
        return layer
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        NotificationCenter.default.addObserver(self, selector: #selector(ScanView.enterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ScanView.enterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Private
    
    private func buildMaskLayer(maskRect: CGRect, interestRect: CGRect) -> CAShapeLayer {
        let path = UIBezierPath(rect: maskRect)
        let excludePath = UIBezierPath(rect: interestRect).reversing()
        path.append(excludePath)
        
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.black.withAlphaComponent(0.4).cgColor
        layer.path = path.cgPath
        
        return layer
    }
    
    @objc func enterBackground() {
        stopScanAnimation()
    }
    
    @objc func enterForeground() {
        startScanAnimation()
    }
    
    // MARK: - Public Methods
    
    func startScanAnimation() {
        
        let animation = CABasicAnimation(keyPath: "position.y")
        animation.fromValue = 0
        animation.toValue = interestRect.height - scanMargin * 2
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
        animation.repeatCount = Float.infinity
        animation.duration = 2.5
        lineLayer.add(animation, forKey: nil)
    }
    
    func stopScanAnimation() {
        lineLayer.removeAllAnimations()
    }
    
    // MARK: - Lift Cycle
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        
        let actualRect = CGRect(x: interestRect.minX + scanMargin, y: interestRect.minY + scanMargin, width: (interestRect.width - scanMargin * 2.0), height: (interestRect.height - scanMargin * 2.0))
        let maskLayer = buildMaskLayer(maskRect: UIScreen.main.bounds, interestRect: actualRect)
        self.layer.addSublayer(maskLayer)
        
        addSubview(borderImageView)
        borderImageView.layer.addSublayer(lineLayer)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        borderImageView.frame = interestRect
        lineLayer.frame = CGRect(x: scanMargin, y: scanMargin, width: (interestRect.width - scanMargin * 2.0), height: 3)
    }
}
