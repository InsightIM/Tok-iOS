import Foundation

extension UIButton {
    func emotionSwiftVoiceButtonUI(showKeyboard: Bool) {
        if showKeyboard {
            self.setImage(UIImage(named: "ChatKeyboard"), for: .normal)
            self.setImage(UIImage(named: "ChatKeyboard"), for: .highlighted)
        } else {
            self.setImage(UIImage(named: "ChatAudio"), for: .normal)
            self.setImage(UIImage(named: "ChatAudio"), for: .highlighted)
        }
    }
    
    func replaceEmotionButtonUI(showKeyboard: Bool) {
        if showKeyboard {
            self.setImage(UIImage(named: "ChatKeyboard"), for: .normal)
            self.setImage(UIImage(named: "ChatKeyboard"), for: .highlighted)
        } else {
            self.setImage(UIImage(named: "ChatAudio"), for: .normal)
            self.setImage(UIImage(named: "ChatAudio"), for: .highlighted)
        }
    }
}


