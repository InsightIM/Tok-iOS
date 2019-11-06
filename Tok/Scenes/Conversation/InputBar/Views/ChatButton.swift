import Foundation

class ChatButton: UIButton {
    var showTypingKeyboard: Bool
    
    required init(coder aDecoder: NSCoder) {
        self.showTypingKeyboard = true
        super.init(coder: aDecoder)!
    }
}
