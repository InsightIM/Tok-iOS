import UIKit
import SnapKit
import RxSwift

private let kLeftRightPadding: CGFloat = 15.0
private let kTopBottomPadding: CGFloat = 10.0
private let kItemCountOfRow: CGFloat = 4

class ChatShareMoreView: UIView {
    @IBOutlet weak var pageControl: UIPageControl!
    @IBOutlet weak var listCollectionView: UICollectionView! {didSet {
        listCollectionView.scrollsToTop = false
        }}
    
    weak var delegate: ChatShareMoreViewDelegate?
    internal let disposeBag = DisposeBag()

    fileprivate let itemDataSouce: [(name: String, iconImage: UIImage)] = [
        (NSLocalizedString("Album", comment: ""), UIImage(named: "MenuAlbum")!),
        (NSLocalizedString("Camera", comment: ""), UIImage(named: "MenuCamera")!),
        (NSLocalizedString("Call", comment: ""), UIImage(named: "MenuCall")!),
        (NSLocalizedString("File", comment: ""), UIImage(named: "MenuFile")!),
    ]
    fileprivate var groupDataSouce = [[(name: String, iconImage: UIImage)]]()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.initialize()
    }
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
        self.initialize()
    }
    
    convenience init() {
        self.init(frame: CGRect.zero)
        self.initialize()
    }
    
    func initialize() {
    }
    
    override func awakeFromNib() {
        let layout = FullyHorizontalFlowLayout()
        layout.minimumLineSpacing = 8
        layout.minimumInteritemSpacing = 0
        layout.sectionInset = UIEdgeInsets(
            top: kTopBottomPadding,
            left: kLeftRightPadding,
            bottom: kTopBottomPadding,
            right: kLeftRightPadding
        )
        //Calculate the UICollectionViewCell size
        let itemSizeWidth = (UIScreen.main.bounds.width - kLeftRightPadding*2 - layout.minimumLineSpacing*(kItemCountOfRow - 1)) / kItemCountOfRow
        let itemSizeHeight = (200 - kTopBottomPadding*2)/2
        layout.itemSize = CGSize(width: itemSizeWidth, height: itemSizeHeight)
        
        self.listCollectionView.collectionViewLayout = layout
        self.listCollectionView.register(ChatShareMoreCollectionViewCell.ts_Nib(), forCellWithReuseIdentifier: ChatShareMoreCollectionViewCell.ts_identifier)
        self.listCollectionView.showsHorizontalScrollIndicator = false
        self.listCollectionView.isPagingEnabled = true
        listCollectionView.backgroundColor = UIColor("#F5F6FA")
        
        /**
        The section count is come from the groupDataSource, and The pageControl.numberOfPages is equal to the groupDataSouce.count.
        So I cut the itemDataSouce into 2 arrays. And the UICollectionView will has 2 sections.
        And then set the minimumLineSpacing and sectionInset of the flowLayout. The UI will be perfect like WeChat.
        */
        self.groupDataSouce = Dollar.chunk(self.itemDataSouce, size: Int(kItemCountOfRow)*2)
        self.pageControl.numberOfPages = self.groupDataSouce.count
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        //Fix the width
        self.listCollectionView.width = UIScreen.main.bounds.width
    }

}

// MARK: - @protocol UICollectionViewDelegate
extension ChatShareMoreView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let delegate = self.delegate else {
            return
        }

        let section = indexPath.section
        let row = indexPath.row
        if section == 0 {
            switch row {
            case 0: delegate.chatShareMoreViewPhotoTaped()
            case 1: delegate.chatShareMoreViewCameraTaped()
            case 2: delegate.chatShareMoreViewAudioCallTaped()
            case 3: delegate.chatShareMoreViewFileTaped()
            default: break
            }
        }
    }
}

// MARK: - @protocol UICollectionViewDataSource
extension ChatShareMoreView: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return self.groupDataSouce.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let subArray = self.groupDataSouce.get(index: section) else {
            return 0
        }
        return subArray.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ChatShareMoreCollectionViewCell.ts_identifier, for: indexPath) as! ChatShareMoreCollectionViewCell
        guard let subArray = self.groupDataSouce.get(index: indexPath.section) else {
            return ChatShareMoreCollectionViewCell()
        }
        if let item = subArray.get(index: indexPath.row) {
            cell.itemButton.setImage(item.iconImage, for: .normal)
            cell.itemLabel.text = item.name
        }
        return cell
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    }
}

// MARK: - @protocol UIScrollViewDelegate
extension ChatShareMoreView: UIScrollViewDelegate {
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let pageWidth: CGFloat = self.listCollectionView.width
        self.pageControl.currentPage = Int(self.listCollectionView.contentOffset.x / pageWidth)
    }
}

 // MARK: - @delgate ChatShareMoreViewDelegate
protocol ChatShareMoreViewDelegate: class {
    
    func chatShareMoreViewPhotoTaped()
    
    func chatShareMoreViewCameraTaped()
    
    func chatShareMoreViewFileTaped()
    
    func chatShareMoreViewAudioCallTaped()
}
