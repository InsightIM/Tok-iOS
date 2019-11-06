import Foundation
import UIKit

extension UILabel {
    func ff_startAnimation(_ ffanimation : FFAnimation, finished: (() -> Void)?){
        ffanimation.startAnimation(for: self, finished: finished)
    }
    
    func ff_textBounds() -> CGRect?{
        guard let text = self.text as NSString? else {return nil}
        return text.boundingRect(with: CGSize(width: self.frame.size.width, height: CGFloat.greatestFiniteMagnitude), options: NSStringDrawingOptions.usesLineFragmentOrigin, attributes: [NSAttributedString.Key.font:self.font!], context: nil)
    }
    
    func ff_textFrame() -> CGRect?{
        guard let textBounds = self.ff_textBounds() else {return nil}
        var stringX:CGFloat = 0;
        let stringH:CGFloat = textBounds.size.height;
        let stringY:CGFloat = (self.frame.size.height - stringH)*0.5;
        let stringW:CGFloat = textBounds.size.width;
        
        switch (self.textAlignment) {
        case .natural,.left,.justified:
            stringX = 0;
            break;
        case .center:
            stringX = (self.frame.size.width - stringW)*0.5;
            break;
        case .right:
            stringX = self.frame.size.width - stringW;
            break;
        @unknown default:
            fatalError()
        }
        return CGRect(x: stringX + self.frame.origin.x, y: stringY + self.frame.origin.y, width: stringW, height: stringH)
    }
    
    func ff_lines() -> [String]{
        guard let text = self.text else {return []}
        //guard let textBounds = self.ff_textBounds() else {return []}
        let attStr = NSMutableAttributedString(string: text)
        attStr.addAttribute(NSAttributedString.Key.font, value: self.font!, range: NSMakeRange(0, attStr.length))
        let frameSetter = CTFramesetterCreateWithAttributedString(attStr)
        let path = CGMutablePath()
        path.addRect(CGRect(x: 0, y: 0, width: self.frame.size.width, height: CGFloat.greatestFiniteMagnitude))
        let frame = CTFramesetterCreateFrame(frameSetter, CFRangeMake(0, 0), path, nil);
        let lines = CTFrameGetLines(frame) as NSArray
        var linesArray : [String] = []
        for line in lines{
            let lineRange = CTLineGetStringRange(line as! CTLine)
            let range = NSMakeRange(lineRange.location, lineRange.length)
            linesArray.append((text as NSString).substring(with: range))
        }
        return linesArray
    }
    
    func ff_charLabels() -> [FFCharLabel] {
        guard let textFrame = self.ff_textFrame() else {return []}
        var xOffset = textFrame.origin.x
        var yOffset = textFrame.origin.y
        var labels :[FFCharLabel] = []
        for str in self.ff_lines(){
            let nsstr = str as NSString
            switch (self.textAlignment) {
            case .natural,.left,.justified:
                xOffset = textFrame.origin.x
                break;
            case .center:
                xOffset = textFrame.origin.x + (textFrame.size.width - nsstr.ff_sizeWithFont(self.font).width)*0.5
                break;
            case .right:
                xOffset = textFrame.origin.x + textFrame.size.width - nsstr.ff_sizeWithFont(self.font).width
                break;
            @unknown default:
                fatalError()
            }
            for  i in 0..<nsstr.length{
                let char = nsstr.substring(with: NSMakeRange(i, 1)) as NSString
                let charSize = char.ff_sizeWithFont(self.font)
                let charLabel = FFCharLabel(frame: CGRect(x: xOffset, y: yOffset, width: charSize.width, height: charSize.height))
                charLabel.font = self.font
                charLabel.textColor = self.textColor
                if(self.backgroundColor != nil){
                    charLabel.backgroundColor = self.backgroundColor
                }
                charLabel.text = char as String
                xOffset += charSize.width
                labels.append(charLabel)
            }
            yOffset += self.font.lineHeight
        }
        return labels
    }
}

class FFStringFlyAnimation : FFAnimation {
    
    var appearDuration : TimeInterval = 0.2
    private var link : CADisplayLink?
    private var charLabels : [FFCharLabel]?
    private var next = 0
    private var animating = false
    
    override func startAnimation(for targetView : UIView, finished: (() -> Void)?) {
        if link != nil{
            return
        }
        self.targetView = targetView
        self.finished = finished
        guard let targetLabel = targetView as? UILabel else {
            return
        }
        targetLabel.isHidden = true
        //guard let text = targetLabel.text else {return}
        print(targetLabel.ff_textBounds()!)
        //print(targetLabel.ff_linesForWidth(targetLabel.ff_textBounds()!.size.width))
        print(targetLabel.ff_lines())
        guard let superView = targetLabel.superview else {return}
        charLabels = targetLabel.ff_charLabels()
        for charLabel in charLabels!{
            charLabel.isHidden = true
            charLabel.old_center = CGPoint(x: charLabel.center.x, y: charLabel.center.y)
            charLabel.center.x = targetLabel.frame.origin.x + targetLabel.frame.width + 100
            superView.addSubview(charLabel)
        }
        link = CADisplayLink(target: self, selector: #selector(display))
        next = 0
        link?.add(to: RunLoop.main, forMode: RunLoop.Mode.common)
    }
    
    func stopAnimation() {
        link?.invalidate()
        link = nil
        finished?()
    }
    
    override func clear() {
        guard let charLabels = self.charLabels else { return }
        for charLabel in charLabels {
            charLabel.removeFromSuperview()
        }
        self.charLabels = nil
    }
    
    @objc func display(){
        if animating{
            return
        }
        guard let charLabels = self.charLabels else {return}
        let charLabel = charLabels[next]
        animating = true
        UIView.setAnimationCurve(.easeInOut)
        charLabel.isHidden = false
        UIView.animate(withDuration: self.appearDuration, animations: {
            if charLabel.old_center != nil{
                charLabel.center = charLabel.old_center!
            }
        }) { (done) in
            self.animating = false
        }
        next += 1
        if next == charLabels.count{
            if self.bRepeat{
                for charLabel in charLabels{
                    charLabel.isHidden = true
                    charLabel.old_center = CGPoint(x: charLabel.center.x, y: charLabel.center.y)
                    charLabel.center.x = self.targetView!.frame.origin.x + self.targetView!.frame.width + 100
                }
                next = 0
            }else{
                self.stopAnimation()
                self.targetView?.isHidden = false
                for charLabel in charLabels{
                    charLabel.removeFromSuperview()
                }
                self.charLabels = nil
            }
        }
    }
}

class FFStringAppear1by1Animation : FFAnimation {
    
    var appearDuration : TimeInterval = 0.2
    private var link : CADisplayLink?
    private var charLabels : [FFCharLabel]?
    private var next = 0
    private var animating = false
    
    override func startAnimation(for targetView: UIView, finished: (() -> Void)?){
        if link != nil{
            return
        }
        self.targetView = targetView
        self.finished = finished
        guard  let targetLabel = targetView as? UILabel else {
            return
        }
        targetLabel.isHidden = true
        //guard let text = targetLabel.text else {return}
        print(targetLabel.ff_textBounds()!)
        //print(targetLabel.ff_linesForWidth(targetLabel.ff_textBounds()!.size.width))
        print(targetLabel.ff_lines())
        guard let superView = targetLabel.superview else {return}
        charLabels = targetLabel.ff_charLabels()
        for charLabel in charLabels!{
            charLabel.alpha = 0
            superView.addSubview(charLabel)
        }
        link = CADisplayLink(target: self, selector: #selector(display))
        next = 0
        link?.add(to: RunLoop.main, forMode: .common)
    }
    
    override func clear() {
        guard let charLabels = self.charLabels else { return }
        for charLabel in charLabels {
            charLabel.removeFromSuperview()
        }
        self.charLabels = nil
    }
    
    func stopAnimation(){
        link?.invalidate()
        link = nil
    }
    
    @objc func display(){
        if animating{
            return
        }
        guard let charLabels = self.charLabels else {return}
        let charLabel = charLabels[next]
        animating = true
        UIView.setAnimationCurve(.easeIn)
        UIView.animate(withDuration: self.appearDuration, animations: {
            charLabel.alpha = 1
        }) { (done) in
            self.animating = false
        }
        next += 1
        if next == charLabels.count{
            if self.bRepeat{
                for charLabel in charLabels{
                    charLabel.alpha = 0
                }
                next = 0
            } else {
                self.stopAnimation()
                finished?()
//                self.targetView?.isHidden = false
//                for charLabel in charLabels{
//                    charLabel.removeFromSuperview()
//                }
//                self.charLabels = nil
            }
        }
    }
}

class FFStringBackToOrderAnimation : FFAnimation{
    
    private var charLabels : [FFCharLabel]?
    
    override func startAnimation(for targetView : UIView, finished: (() -> Void)?) {
        self.targetView = targetView
        guard  let targetLabel = targetView as? UILabel else {
            return
        }
        targetLabel.isHidden = true
        //guard let text = targetLabel.text else {return}
        print(targetLabel.ff_textBounds()!)
        //print(targetLabel.ff_linesForWidth(targetLabel.ff_textBounds()!.size.width))
        print(targetLabel.ff_lines())
        guard let superView = targetLabel.superview else {return}
        charLabels = targetLabel.ff_charLabels()
        for charLabel in charLabels!{
            charLabel.old_center = CGPoint(x: charLabel.center.x, y: charLabel.center.y)
            charLabel.center.x = CGFloat(arc4random_uniform(UInt32(targetLabel.frame.size.width)))
            charLabel.center.y = CGFloat(arc4random_uniform(UInt32(targetLabel.frame.size.height)))
            superView.addSubview(charLabel)
        }
        UIView.setAnimationCurve(.easeInOut)
        UIView.animate(withDuration: duration, animations: {
            for charLabel in self.charLabels!{
                if charLabel.old_center != nil{
                    charLabel.center = charLabel.old_center!
                }
            }
        }) { _ in
            
        }
    }
}
