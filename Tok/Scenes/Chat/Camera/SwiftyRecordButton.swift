import UIKit
import SwiftyCam

class SwiftyRecordButton: SwiftyCamButton {
    
    private var circleBorder: CALayer!
    private var innerCircle: UIView!
    lazy var progress = UICircularProgressRing()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        drawButton()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        drawButton()
    }
    
    private func drawButton() {
        self.backgroundColor = UIColor.clear
        
        circleBorder = CALayer()
        circleBorder.backgroundColor = UIColor.clear.cgColor
        circleBorder.borderWidth = 6.0
        circleBorder.borderColor = UIColor.white.cgColor
        layer.insertSublayer(circleBorder, at: 0)
        
        progress.outerRingWidth = 0
        progress.innerRingColor = UIColor.red
        progress.innerRingWidth = 6
        progress.innerRingSpacing = 0
        progress.innerCapStyle = .square
        progress.startAngle = 270
        progress.shouldShowValueText = false
        
        addSubview(progress)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        circleBorder.bounds = self.bounds
        circleBorder.position = CGPoint(x: self.bounds.midX, y: self.bounds.midY)
        circleBorder.cornerRadius = self.frame.size.width / 2
        
        progress.frame = CGRect(origin: .zero, size: CGSize(width: bounds.width * 1.3, height: bounds.height * 1.3))
        progress.center = CGPoint(x: self.bounds.midX, y: self.bounds.midY)
    }
    
    public func growButton() {
        
        innerCircle = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        innerCircle.center = CGPoint(x: self.bounds.midX, y: self.bounds.midY)
        innerCircle.backgroundColor = UIColor.red
        innerCircle.layer.cornerRadius = innerCircle.frame.size.width / 2
        innerCircle.clipsToBounds = true
        self.addSubview(innerCircle)
        
        UIView.animate(withDuration: 0.3, delay: 0.0, options: .curveEaseOut, animations: {
            self.innerCircle.transform = CGAffineTransform(scaleX: 62, y: 62)
            self.circleBorder.setAffineTransform(CGAffineTransform(scaleX: 1.3, y: 1.3))
            self.circleBorder.borderWidth = (6 / 1.3)
        }, completion: { _ in
            self.progress.startProgress(to: 100, duration: 10)
        })
    }
    
    public func shrinkButton() {
        progress.resetProgress()
        UIView.animate(withDuration: 0.3, delay: 0.0, options: .curveEaseOut, animations: {
            self.innerCircle.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
            self.circleBorder.setAffineTransform(CGAffineTransform(scaleX: 1.0, y: 1.0))
            self.circleBorder.borderWidth = 6.0
        }, completion: { (success) in
            self.innerCircle.removeFromSuperview()
            self.innerCircle = nil
        })
    }
}
