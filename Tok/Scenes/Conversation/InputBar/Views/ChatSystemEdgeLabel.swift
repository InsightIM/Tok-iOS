import UIKit

final class ChatEdgeLabel: UILabel {
    var labelEdge: UIEdgeInsets = UIEdgeInsets(top: 0, left: 7, bottom: 0, right: 7)

    /*
    // Only override drawRect: if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func drawRect(rect: CGRect) {
        // Drawing code
    }
    */
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: labelEdge))
    }
}
