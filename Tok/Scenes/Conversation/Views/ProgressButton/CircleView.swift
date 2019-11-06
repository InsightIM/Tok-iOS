import UIKit

final class CircleView: UIView {
    
    // MARK: Properties
    
    var startAngleRadians: CGFloat = -CGFloat.pi / 2
    
    var endAngleRadians: CGFloat = 3 * CGFloat.pi / 2
    
    var lineWidth: CGFloat = 1 {
        didSet {
            circleLayer.lineWidth = lineWidth
        }
    }
    
    var circleColor: UIColor = UIColor(red: 245.0 / 255.0, green: 244.0 / 255.0, blue: 249.0 / 255.0, alpha: 1) {
        didSet {
            circleLayer.strokeColor = circleColor.cgColor
        }
    }
    
    let circleLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.clear.cgColor
        layer.lineCap = .round
        return layer
    }()

    // MARK: Initializers
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    private func commonInit() {
        backgroundColor = .clear
        circleLayer.strokeColor = circleColor.cgColor
        circleLayer.lineWidth = lineWidth
        layer.addSublayer(circleLayer)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let radius = min(frame.width / 2, frame.height / 2) - lineWidth / 2
        let center = CGPoint(x: frame.width / 2, y: frame.height / 2)
        circleLayer.path = UIBezierPath(arcCenter: center,
                                        radius: radius,
                                        startAngle: startAngleRadians,
                                        endAngle: endAngleRadians,
                                        clockwise: true).cgPath
    }
    
    func startSpinning() {
        let animationKey = "rotation"
        layer.removeAnimation(forKey: animationKey)
        let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation")
        rotationAnimation.fromValue = 0.0
        rotationAnimation.toValue = CGFloat.pi * 2
        rotationAnimation.duration = 2
        rotationAnimation.repeatCount = .greatestFiniteMagnitude;
        layer.add(rotationAnimation, forKey: animationKey)
    }
}
