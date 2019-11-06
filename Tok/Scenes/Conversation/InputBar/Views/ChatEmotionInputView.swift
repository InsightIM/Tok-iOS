//
//  ChatEmotionInputView.swift
//  Tok
//
//  Created by Hilen on 12/16/15.
//  Copyright © 2018 Insight. All rights reserved.
//

import UIKit
import RxSwift

private let itemHeight: CGFloat = 50
private let kOneGroupCount = 23
private let kNumberOfOneRow: CGFloat = 8

class ChatEmotionInputView: UIView {
    static let ExpressionPlist = Bundle.main.path(forResource: "Expression", ofType: "plist")
    
    @IBOutlet fileprivate weak var emotionPageControl: UIPageControl!
    @IBOutlet fileprivate weak var sendButton: UIButton!{ didSet{
        sendButton.layer.borderColor = UIColor.lightGray.cgColor
        sendButton.layer.borderWidth = 0.5
        sendButton.layer.cornerRadius = 3.0
        sendButton.layer.masksToBounds = true
        }}

    @IBOutlet fileprivate weak var listCollectionView: ChatEmotionScollView!
    fileprivate var groupDataSouce = [[EmotionModel]]()  //大数组包含小数组
    fileprivate var emotionsDataSouce = [EmotionModel]()  //Model 数组
    weak internal var delegate: ChatEmotionInputViewDelegate?

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
        self.initialize()
    }
        
    func initialize() {

    }
    
    override func awakeFromNib() {
        self.isUserInteractionEnabled = true
        
        //calculate width and height
        let itemWidth = (UIScreen.main.bounds.width - 10 * 2) / kNumberOfOneRow
        let padding = (UIScreen.main.bounds.width - kNumberOfOneRow * itemWidth) / 2.0
        let paddingLeft = padding
        let paddingRight = UIScreen.main.bounds.width - paddingLeft - itemWidth * kNumberOfOneRow
        
        //init FlowLayout
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: itemWidth, height: itemHeight)
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        layout.sectionInset = UIEdgeInsets(top: 0, left: paddingLeft, bottom: 0, right: paddingRight)
        
        //init listCollectionView
        self.listCollectionView.collectionViewLayout = layout
        self.listCollectionView.register(ChatEmotionCell.ts_Nib(), forCellWithReuseIdentifier: ChatEmotionCell.ts_identifier)
        self.listCollectionView.isPagingEnabled = true
        self.listCollectionView.emotionScrollDelegate = self

        //init dataSource
        guard let emojiArray = NSArray(contentsOfFile: ChatEmotionInputView.ExpressionPlist!) else {
            return
        }
        
        for data in emojiArray {
            let model = EmotionModel.init(fromDictionary: data as! NSDictionary)
            self.emotionsDataSouce.append(model)
        }
        self.groupDataSouce = Dollar.chunk(self.emotionsDataSouce, size: kOneGroupCount)  //将数组切割成 每23个 一组
        self.listCollectionView.reloadData()
        self.emotionPageControl.numberOfPages = self.groupDataSouce.count
    }
    
    @IBAction func sendTaped(_ sender: AnyObject) {
        if let delegate = self.delegate {
            delegate.chatEmoticonInputViewDidTapSend()
        }
    }
    
    //transpose line/row
    fileprivate func emoticonForIndexPath(_ indexPath: IndexPath) -> EmotionModel? {
        let page = indexPath.section
        var index = page * kOneGroupCount + indexPath.row
        
        let ip = index / kOneGroupCount
        let ii = index % kOneGroupCount
        let reIndex = (ii % 3) * Int(kNumberOfOneRow) + (ii / 3)
        
        index = reIndex + ip * kOneGroupCount
        if index < self.emotionsDataSouce.count {
            return self.emotionsDataSouce[index]
        } else {
            return nil
        }
    }
}

// MARK: - @protocol UICollectionViewDelegate
extension ChatEmotionInputView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        return false
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        return false
    }
}

// MARK: - @protocol UICollectionViewDataSource
extension ChatEmotionInputView: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return self.groupDataSouce.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return kOneGroupCount + 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ChatEmotionCell.ts_identifier, for: indexPath) as! ChatEmotionCell
        if indexPath.row == kOneGroupCount {
            cell.setDeleteCellContnet()
        } else {
            cell.setCellContnet(self.emoticonForIndexPath(indexPath))
        }
        return cell
    }
}

// MARK: - @protocol UIScrollViewDelegate
extension ChatEmotionInputView: UIScrollViewDelegate {
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let pageWidth: CGFloat = self.listCollectionView.width
        self.emotionPageControl.currentPage = Int(self.listCollectionView.contentOffset.x / pageWidth)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.listCollectionView.hideMagnifierView()
        self.listCollectionView.endBackspaceTimer()
    }
}

// MARK: - @protocol UIInputViewAudioFeedback
extension ChatEmotionInputView: UIInputViewAudioFeedback {
    internal var enableInputClicksWhenVisible: Bool {
        get { return true }
    }
}


// MARK: - @protocol ChatEmotionScollViewDelegate
extension ChatEmotionInputView: ChatEmotionScollViewDelegate {
    func emoticonScrollViewDidTapCell(_ cell: ChatEmotionCell) {
        guard let delegate = self.delegate else {
            return
        }
        if cell.isDelete {
            delegate.chatEmoticonInputViewDidTapBackspace(cell)
        } else {
            delegate.chatEmoticonInputViewDidTapCell(cell)
        }
    }
}

// MARK: - @delegate ChatEmotionInputViewDelegate
protocol ChatEmotionInputViewDelegate: class {
    
    func chatEmoticonInputViewDidTapCell(_ cell: ChatEmotionCell)
    
    func chatEmoticonInputViewDidTapBackspace(_ cell: ChatEmotionCell)
    
    func chatEmoticonInputViewDidTapSend()
}
