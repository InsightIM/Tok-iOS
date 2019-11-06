import Foundation
import UIKit

class FFAnimation {
    var targetView : UIView?
    var bRepeat = false
    var duration : TimeInterval = 1
    var finished: (() -> Void)?
    func startAnimation(for targetView: UIView, finished: (() -> Void)?){
        self.targetView = targetView
        self.finished = finished
    }
    
    func clear() {}
}

extension NSString{
    func ff_sizeWithFont(_ font : UIFont) -> CGSize{
        return self.boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: [NSAttributedString.Key.font:font], context: nil).size
    }
}

class FFCharLabel : UILabel{
    var old_center : CGPoint?
}
