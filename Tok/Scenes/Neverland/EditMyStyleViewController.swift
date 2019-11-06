//
//  EditMyStyleViewController.swift
//  Tok
//
//  Created by Bryce on 2019/7/3.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

class EditMyStyleViewController: BaseViewController {

    let disposeBag = DisposeBag()
    let maxCount = 300
    
    var didEdit: (() -> Void)?
    
    lazy var containerView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 4
        view.layer.masksToBounds = true
        view.backgroundColor = .white
        return view
    }()
    
    lazy var textView: UITextView = {
        let textView = UITextView()
        textView.textColor = .tokTitle4
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 15
        textView.typingAttributes = [.paragraphStyle: paragraphStyle,
                                     .font: UIFont.systemFont(ofSize: 16)]
        return textView
    }()
    
    lazy var countLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor("#B5B5BB")
        label.font = UIFont.systemFont(ofSize: 12)
        label.text = "0/\(maxCount)"
        return label
    }()
    
    lazy var moreButton: UIButton = {
        let button = UIButton()
        button.setTitle(NSLocalizedString("Classical words >", comment: ""), for: .normal)
        button.setTitleColor(.tokBlue, for: .normal)
        button.setTitleColor(UIColor.tokBlue.withAlphaComponent(0.5), for: .highlighted)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        return button
    }()
    
    lazy var backItem: UIBarButtonItem = {
       let item = UIBarButtonItem(image: UIImage(named: "Back")?.withRenderingMode(.alwaysTemplate), style: .plain, target: self, action: #selector(self.didBack))
        item.tintColor = .black
        return item
    }()
    
    lazy var doneItem = UIBarButtonItem(title: NSLocalizedString("Done", comment: ""), style: .plain, target: self, action: #selector(self.didDone))
    
    private let findFriendService: FindFriendService
    init(findFriendService: FindFriendService) {
        self.findFriendService = findFriendService
        super.init()
        hidesBottomBarWhenPushed = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("Edit My Style", comment: "")
        view.backgroundColor = .tokBackgroundColor
        
        navigationItem.leftBarButtonItem = backItem
        navigationItem.rightBarButtonItem = doneItem
        
        containerView.addSubview(textView)
        containerView.addSubview(countLabel)
        view.addSubview(containerView)
        view.addSubview(moreButton)
        
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
            make.leading.equalTo(16)
            make.trailing.equalTo(-16)
            make.height.equalTo(280)
        }
        moreButton.snp.makeConstraints { (make) in
            make.top.equalTo(containerView.snp.bottom).offset(8)
            make.trailing.equalTo(-16)
        }
        
        let allCount = findFriendService.loadClassicWords().count
        moreButton.setTitle("\(allCount) \(NSLocalizedString("Classical words >", comment: ""))", for: .normal)
        
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
            .map { $0.count <= self.maxCount && $0.count > 0 }
            .bind(to: doneItem.rx.isEnabled)
            .disposed(by: disposeBag)
        
        moreButton.rx.tap
            .subscribe(onNext: { [unowned self] _ in
                let vc = WordsListViewController(findFriendService: self.findFriendService)
                vc.didSelect = { [weak self] in
                    self?.textView.text = $0
                }
                self.navigationController?.pushViewController(vc, animated: true)
            })
            .disposed(by: disposeBag)
        
        textView.text = findFriendService.bio
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        textView.flashScrollIndicators()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        textView.endEditing(true)
    }
    
    @objc
    func didBack() {
        textView.endEditing(true)
        
        guard textView.text != findFriendService.bio else {
            dismiss(animated: true, completion: nil)
            return
        }
        guard textView.text.count <= maxCount else {
            dismiss(animated: true, completion: nil)
            return
        }
        
        let message = NSLocalizedString("You have changed some words. Apply changes?", comment: "")
        let ok = NSLocalizedString("Apply", comment: "")
        let action: AlertViewManager.Action = { [weak self] in
            self?.didDone()
        }
        
        let cancelAction: AlertViewManager.Action = { [weak self] in
            self?.dismiss(animated: true, completion: nil)
        }
        
        AlertViewManager.showMessageSheet(with: message, actions: [(ok, .destructive, action)], customCancelAction: cancelAction)
    }
    
    @objc
    func didDone() {
        findFriendService.setNewBio(textView.text)
        didEdit?()
        self.dismiss(animated: true, completion: nil)
    }
}
