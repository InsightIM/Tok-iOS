import UIKit

let kChatActionBarMaxRows = 6 // Expandable textview max Rows

protocol ChatActionBarViewDelegate: class {

    func chatActionBarRecordVoiceHideKeyboard()

    func chatActionBarShowEmotionKeyboard()

    func chatActionBarShowShareKeyboard()
}

class ChatActionBarView: UIView {
    
    enum ChatKeyboardType: Int {
        case `default`, text, emotion, share
    }
    
    var keyboardType: ChatKeyboardType? = .default
    weak var delegate: ChatActionBarViewDelegate?
    
    @IBOutlet weak var inputTextView: UITextView! {
        didSet {
            inputTextView.translatesAutoresizingMaskIntoConstraints = false
            inputTextView.font = UIFont.systemFont(ofSize: 17)
            inputTextView.layer.borderColor = UIColor("#ADADAD").cgColor
            inputTextView.layer.borderWidth = 1.0 / UIScreen.main.scale
            inputTextView.layer.cornerRadius = 18
//            inputTextView.layer.masksToBounds = true
            
            inputTextView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
            inputTextView.scrollIndicatorInsets = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
            inputTextView.backgroundColor = UIColor("#FEFFFE")
            inputTextView.returnKeyType = .send
            inputTextView.isHidden = false
            inputTextView.enablesReturnKeyAutomatically = true
            inputTextView.layoutManager.allowsNonContiguousLayout = false
            inputTextView.scrollsToTop = false
            
            let newLineMenu = UIMenuItem(title: NSLocalizedString("New Line", comment: ""), action: #selector(ChatActionBarView.newLineClick))
            UIMenuController.shared.menuItems = [newLineMenu]
        }
    }
    
    @IBOutlet weak var voiceButton: ChatButton!
    @IBOutlet weak var emotionButton: ChatButton! {
        didSet {
            emotionButton.showTypingKeyboard = false
        }
    }
    
    @IBOutlet weak var shareButton: ChatButton! {
        didSet {
            shareButton.showTypingKeyboard = false
        }
    }
    
    @IBOutlet weak var recordButton: AudioInputButton! {
        didSet {
            recordButton.isHidden = true
        }
    }

    override init (frame: CGRect) {
        super.init(frame : frame)
        self.initContent()
    }
    
    convenience init () {
        self.init(frame:CGRect.zero)
        self.initContent()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    func initContent() {
        backgroundColor = UIColor("#FEFFFE")
        
        let topBorder = UIView()
        topBorder.backgroundColor = .tokLine
        self.addSubview(topBorder)
        
        topBorder.snp.makeConstraints { (make) -> Void in
            make.top.left.right.equalToSuperview()
            make.height.equalTo(1.0 / UIScreen.main.scale)
        }
    }
    
    override func awakeFromNib() {
        initContent()
    }
    
    deinit {
    }
    
    @objc
    func newLineClick() {
        if let text = inputTextView.text {
            let location = inputTextView.selectedRange.location
            inputTextView.text.insert("\n", at: text.index(text.startIndex, offsetBy: location))
            inputTextView.selectedRange = NSRange(location: location + 1, length: 0)
        } else {
            inputTextView.text += "\n"
        }
        if let delegate = inputTextView.delegate {
            delegate.textViewDidChange!(inputTextView)
        }
    }
}

// MARK: - @extension ChatActionBarView

extension ChatActionBarView {
    
    func resetButtonUI() {
        self.voiceButton.setImage(UIImage(named: "ChatAudio"), for: .normal)
        
        self.emotionButton.setImage(UIImage(named: "ChatMore"), for: .normal)
        
        self.shareButton.setImage(UIImage(named: "ChatMore"), for: .normal)
    }
    
    func inputTextViewCallKeyboard() {
        self.keyboardType = .text
        self.inputTextView.isHidden = false
        
        self.recordButton.isHidden = true
        self.voiceButton.showTypingKeyboard = false
        self.emotionButton.showTypingKeyboard = false
        self.shareButton.showTypingKeyboard = false
    }
    
    func showTyingKeyboard() {
        self.keyboardType = .text
        self.inputTextView.becomeFirstResponder()
        self.inputTextView.isHidden = false
        
        self.recordButton.isHidden = true
        self.voiceButton.showTypingKeyboard = false
        self.emotionButton.showTypingKeyboard = false
        self.shareButton.showTypingKeyboard = false
    }
    
    func showRecording() {
        self.keyboardType = .default
        self.inputTextView.resignFirstResponder()
        self.inputTextView.isHidden = true
        if let delegate = self.delegate {
            delegate.chatActionBarRecordVoiceHideKeyboard()
        }
        self.recordButton.isHidden = false
        self.voiceButton.showTypingKeyboard = true
        self.emotionButton.showTypingKeyboard = false
        self.shareButton.showTypingKeyboard = false
    }
    
    func showEmotionKeyboard() {
        self.keyboardType = .emotion
        self.inputTextView.resignFirstResponder()
        self.inputTextView.isHidden = false
        if let delegate = self.delegate {
            delegate.chatActionBarShowEmotionKeyboard()
        }
        
        self.recordButton.isHidden = true
        self.emotionButton.showTypingKeyboard = true
        self.shareButton.showTypingKeyboard = false
    }
    
    func showShareKeyboard() {
        self.keyboardType = .share
        self.inputTextView.resignFirstResponder()
        self.inputTextView.isHidden = false
        if let delegate = self.delegate {
            delegate.chatActionBarShowShareKeyboard()
        }

        self.recordButton.isHidden = true
        self.emotionButton.showTypingKeyboard = false
        self.shareButton.showTypingKeyboard = true
    }
    
    func resignKeyboard() {
        self.keyboardType = .default
        self.inputTextView.resignFirstResponder()
        
        self.emotionButton.showTypingKeyboard = false
        self.shareButton.showTypingKeyboard = false
    }
    
    fileprivate func changeTextViewCursorColor(_ color: UIColor) {
        self.inputTextView.tintColor = color
        UIView.setAnimationsEnabled(false)
        self.inputTextView.resignFirstResponder()
        self.inputTextView.becomeFirstResponder()
        UIView.setAnimationsEnabled(true)
    }
}
