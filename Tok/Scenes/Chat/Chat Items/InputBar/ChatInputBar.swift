//
//  ChatInputBarView.swift
//  Tok
//
//  Created by Bryce on 2019/5/20.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import SnapKit
import Chatto
import ChattoAdditions

protocol ChatInputBarDelegate: class {
    var menuDelegate: ChatMoreActionViewDelegate? { get }
    
    func onSendButtonPressed(text: String)
    
    func onSendAudioMessage(url: URL, duration: UInt)
}

final class ChatInputBar: ReusableXibView {
    
    var maxCharactersCount: Int?
    var chatInputItems: [ChatInputItemProtocol]!
    var isGroup: Bool = false
    
    weak var presenter: ChatInputBarViewPresenter?
    weak var delegate: ChatInputBarDelegate? {
        didSet {
            let focusOnInputItem: BaseInuptItem.Action = { [weak self] inputItem in
                self?.presenter?.onDidReceiveFocusOnItem(inputItem)
            }
            
            let selectionChanged: BaseInuptItem.Action = { [weak self] inputItem in
                if inputItem.presentationMode == .keyboard {
                    self?.recordButton.isHidden = true
                    self?.textView.isHidden = false
                } else {
                    self?.recordButton.isHidden = false
                    self?.textView.isHidden = true
                }
            }
            
            let menu = MenuInputItem(tabView: moreButton, action: focusOnInputItem)
            menu.isGroup = isGroup
            menu.delegate = delegate?.menuDelegate
            
            chatInputItems = [
                menu,
                AudioInputItem(tabView: voiceButton, action: focusOnInputItem, selectionChanged: selectionChanged)
            ]
        }
    }
    
    @IBOutlet weak var textView: ExpandableTextView! {
        didSet {
            textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
            textView.scrollIndicatorInsets = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
            textView.font = UIFont.systemFont(ofSize: 17)
            textView.layer.borderColor = UIColor("#ADADAD").cgColor
            textView.layer.borderWidth = 1.0 / UIScreen.main.scale
            textView.layer.cornerRadius = 18
            textView.delegate = self
        }
    }
    
    @IBOutlet weak var moreButton: UIButton!
    @IBOutlet weak var voiceButton: UIButton!
    @IBOutlet weak var recordButton: AudioInputButton! {
        didSet {
            recordButton.isHidden = true
            recordButton.didRecord = { [weak self] (url, duration) in
                self?.delegate?.onSendAudioMessage(url: url, duration: duration)
            }
        }
    }
    
    class func loadNib() -> ChatInputBar {
        let view = Bundle(for: self).loadNibNamed(self.nibName(), owner: nil, options: nil)!.first as! ChatInputBar
        view.translatesAutoresizingMaskIntoConstraints = false
        view.frame = CGRect.zero
        return view
    }
    
    class func nibName() -> String {
        return "ChatInputBar"
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
        super.awakeFromNib()
        initContent()
    }
}

// MARK: UITextViewDelegate
extension ChatInputBar: UITextViewDelegate {
    public func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        return true
    }
    
    public func textViewDidEndEditing(_ textView: UITextView) {
        self.presenter?.onDidEndEditing(force: false)
    }
    
    public func textViewDidBeginEditing(_ textView: UITextView) {
        self.presenter?.onDidBeginEditing()
    }
    
    public func textViewDidChange(_ textView: UITextView) {
    }
    
    public func textView(_ textView: UITextView, shouldChangeTextIn nsRange: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            delegate?.onSendButtonPressed(text: textView.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))
            textView.text = ""
            return false
        }
        let range = self.textView.text.bma_rangeFromNSRange(nsRange)
        if let maxCharactersCount = self.maxCharactersCount {
            let currentCount = textView.text.count
            let rangeLength = textView.text[range].count
            let nextCount = currentCount - rangeLength + text.count
            return UInt(nextCount) <= maxCharactersCount
        }
        return true
    }
}

private extension String {
    func bma_rangeFromNSRange(_ nsRange: NSRange) -> Range<String.Index> {
        guard
            let from16 = utf16.index(utf16.startIndex, offsetBy: nsRange.location, limitedBy: utf16.endIndex),
            let to16 = utf16.index(from16, offsetBy: nsRange.length, limitedBy: utf16.endIndex),
            let from = String.Index(from16, within: self),
            let to = String.Index(to16, within: self)
            else { return  self.startIndex..<self.startIndex }
        return from ..< to
    }
}
