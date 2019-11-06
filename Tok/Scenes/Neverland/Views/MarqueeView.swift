import UIKit

public protocol JXMarqueeViewCopyable {
    func copyMarqueeView() -> UIView
}

extension UIView: JXMarqueeViewCopyable {
    @objc public func copyMarqueeView() -> UIView {
        let archivedData = NSKeyedArchiver.archivedData(withRootObject: self)
        let copyView = NSKeyedUnarchiver.unarchiveObject(with: archivedData) as! UIView
        return copyView
    }
}

public enum JXMarqueeType {
    case left
    case right
    case top
    case reverse
}

public class JXMarqueeView: UIView {
    public var marqueeType: JXMarqueeType = .top
    public var contentMargin: CGFloat = 12
    public var frameInterval: Int = 20
    public var pointsPerFrame: CGFloat = 1
    public var contentView: UIView? {
        didSet {
            self.setNeedsLayout()
        }
    }
    public var contentViewFrameConfigWhenCantMarquee: ((UIView)->())?
    private let containerView = UIView()
    private var marqueeDisplayLink: CADisplayLink?
    private var isReversing = false

    deinit {
        contentViewFrameConfigWhenCantMarquee = nil
    }

    override open func willMove(toSuperview newSuperview: UIView?) {
        if newSuperview == nil {
            self.stop()
        }
    }

    public init() {
        super.init(frame: CGRect.zero)

        self.initializeViews()
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)

        self.initializeViews()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        self.initializeViews()
    }

    func initializeViews() {
        self.backgroundColor = UIColor.clear
        self.clipsToBounds = true

        containerView.backgroundColor = UIColor.clear
        self.addSubview(containerView)
    }

    override open func layoutSubviews() {
        super.layoutSubviews()

        guard let validContentView = contentView else {
            return
        }
        for view in containerView.subviews {
            view.removeFromSuperview()
        }

        validContentView.sizeToFit()
        containerView.addSubview(validContentView)

        containerView.frame = CGRect(x: 0, y: self.height, width: self.width, height: validContentView.height)
        validContentView.frame = CGRect(x: 0, y: 0, width: self.width, height: validContentView.height)
        startMarquee()
    }

    public func reloadData() {
        self.setNeedsLayout()
    }

    fileprivate func startMarquee() {
        self.stop()

        self.marqueeDisplayLink = CADisplayLink.init(target: self, selector: #selector(processMarquee))
        self.marqueeDisplayLink?.preferredFramesPerSecond = self.frameInterval
        self.marqueeDisplayLink?.add(to: RunLoop.main, forMode: RunLoop.Mode.common)
    }

    public func stop()  {
        self.marqueeDisplayLink?.invalidate()
        self.marqueeDisplayLink = nil
    }

    @objc fileprivate func processMarquee() {
        var frame = self.containerView.frame

        switch marqueeType {
        case .top:
            let targetY = -contentView!.height
            if frame.origin.y <= targetY {
                frame.origin.y = self.height
                self.containerView.frame = frame
            } else {
                frame.origin.y -= pointsPerFrame
                if frame.origin.y < targetY {
                    frame.origin.y = targetY
                }
                self.containerView.frame = frame
            }
        case .left:
            let targetX = -(self.contentView!.bounds.size.width + self.contentMargin)
            if frame.origin.x <= targetX {
                frame.origin.x = 0
                self.containerView.frame = frame
            }else {
                frame.origin.x -= pointsPerFrame
                if frame.origin.x < targetX {
                    frame.origin.x = targetX
                }
                self.containerView.frame = frame
            }
        case .right:
            let targetX = self.bounds.size.width - self.contentView!.bounds.size.width
            if frame.origin.x >= targetX {
                frame.origin.x = self.bounds.size.width - self.containerView.bounds.size.width
                self.containerView.frame = frame
            }else {
                frame.origin.x += pointsPerFrame
                if frame.origin.x > targetX {
                    frame.origin.x = targetX
                }
                self.containerView.frame = frame
            }
        case .reverse:
            if isReversing {
                let targetX: CGFloat = 0
                if frame.origin.x > targetX {
                    frame.origin.x = 0
                    self.containerView.frame = frame
                    isReversing = false
                }else {
                    frame.origin.x += pointsPerFrame
                    if frame.origin.x > 0 {
                        frame.origin.x = 0
                        isReversing = false
                    }
                    self.containerView.frame = frame
                }
            }else {
                let targetX = self.bounds.size.width - self.containerView.bounds.size.width
                if frame.origin.x <= targetX {
                    isReversing = true
                }else {
                    frame.origin.x -= pointsPerFrame
                    if frame.origin.x < targetX {
                        frame.origin.x = targetX
                        isReversing = true
                    }
                    self.containerView.frame = frame
                }
            }
        }
    }
}
