//
//  ChangeGroupDescViewController.swift
//  Tok
//
//  Created by Bryce on 2019/7/9.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

class ChangeGroupDescViewController: BaseViewController {
    
    let maxCount = 300
    let disposeBag = DisposeBag()

    lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        return view
    }()
    
    lazy var textView: UITextView = {
        let textView = UITextView()
        textView.textColor = .tokTitle4
        textView.typingAttributes = [.font: UIFont.systemFont(ofSize: 16)]
        return textView
    }()
    
    lazy var countLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor("#B5B5BB")
        label.font = UIFont.systemFont(ofSize: 12)
        label.text = "0/\(maxCount)"
        return label
    }()
    
    private let chat: OCTChat
    private let manager: OCTManager
    
    init(chat: OCTChat, toxManager: OCTManager) {
        self.chat = chat
        self.manager = toxManager
        
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Group Description", comment: "")

        let cancelItem = UIBarButtonItem(title: NSLocalizedString("Cancel", comment: ""), style: .plain, target: self, action: #selector(self.didCancel))
        navigationItem.leftBarButtonItem = cancelItem
        let doneItem = UIBarButtonItem(title: NSLocalizedString("Done", comment: ""), style: .plain, target: self, action: #selector(self.didDone))
        navigationItem.rightBarButtonItem = doneItem
        
        view.backgroundColor = .tokBackgroundColor
        
        containerView.addSubview(textView)
        containerView.addSubview(countLabel)
        view.addSubview(containerView)
        
        textView.snp.makeConstraints { (make) in
            make.top.leading.equalTo(14)
            make.bottom.equalTo(countLabel.snp.top).offset(-6)
            make.trailing.equalTo(-14)
        }
        countLabel.snp.makeConstraints { (make) in
            make.right.bottom.equalTo(-14)
        }
        containerView.snp.makeConstraints { (make) in
            make.top.equalTo(16)
            make.leading.equalTo(0)
            make.trailing.equalTo(0)
            make.height.equalTo(280)
        }
        
        textView.text = chat.groupDescription
        
        textView.rx.text.orEmpty
            .map { [unowned self] text in
                let string = "\(text.count)/\(self.maxCount)"
                return text.count > self.maxCount
                    ? NSAttributedString(string: string, attributes: [.foregroundColor: UIColor.tokNotice])
                    : NSAttributedString(string: string, attributes: [.foregroundColor: UIColor("#B5B5BB")])
            }
            .bind(to: countLabel.rx.attributedText)
            .disposed(by: disposeBag)
        
        textView.rx.text.orEmpty
            .map { $0.count <= self.maxCount && $0.trimmingCharacters(in: .whitespacesAndNewlines).count > 0 }
            .bind(to: doneItem.rx.isEnabled)
            .disposed(by: disposeBag)
    }
    
    @objc
    private func didDone() {
        manager.chats.setGroupRemarkWithGroupNumber(chat.groupNumber, remark: textView.text.trimmingCharacters(in: .whitespacesAndNewlines))
        dismiss(animated: true, completion: nil)
    }
    
    @objc
    private func didCancel() {
        dismiss(animated: true, completion: nil)
    }
}
