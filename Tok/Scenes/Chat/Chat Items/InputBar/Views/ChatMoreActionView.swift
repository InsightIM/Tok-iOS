import UIKit

class ChatMoreActionView: UIView {

    @IBOutlet weak var listCollectionView: UICollectionView! {
        didSet {
            listCollectionView.backgroundColor = UIColor("#F5F6FA")
            listCollectionView.register(ChatMoreActionCollectionViewCell.ts_Nib(), forCellWithReuseIdentifier: ChatMoreActionCollectionViewCell.ts_identifier)
            listCollectionView.showsHorizontalScrollIndicator = false
            listCollectionView.isPagingEnabled = true
        }
    }
    @IBOutlet weak var collectionViewLayout: UICollectionViewFlowLayout!
    
    var isGroup = false {
        didSet {
            updateDataSource()
        }
    }
    weak var delegate: ChatMoreActionViewDelegate?

    private let itemCountPerLine: CGFloat = 4
    private var availableWidth: CGFloat = 0
    
    fileprivate lazy var itemDataSouce = [(name: String, iconImage: UIImage, (() -> Void))]()
    
    private func updateDataSource() {
        let album: (name: String, iconImage: UIImage, (() -> Void)) = (NSLocalizedString("Album", comment: ""), UIImage(named: "MenuAlbum")!, { [weak self] in
            self?.delegate?.chatShareMoreViewPhotoTaped()
        })
        let camera: (name: String, iconImage: UIImage, (() -> Void)) = (NSLocalizedString("Camera", comment: ""), UIImage(named: "MenuCamera")!, { [weak self] in
            self?.delegate?.chatShareMoreViewCameraTaped()
        })
        let call: (name: String, iconImage: UIImage, (() -> Void)) = (NSLocalizedString("Call", comment: ""), UIImage(named: "MenuCall")!, { [weak self] in
            self?.delegate?.chatShareMoreViewAudioCallTaped()
        })
        let file: (name: String, iconImage: UIImage, (() -> Void)) = (NSLocalizedString("File", comment: ""), UIImage(named: "MenuFile")!, { [weak self] in
            self?.delegate?.chatShareMoreViewFileTaped()
        })
        itemDataSouce = isGroup
            ? [album, camera, file]
            : [album, camera, call, file]
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let width = bounds.width - UIApplication.safeAreaInsets.bma_horziontalInset
        if availableWidth != width {
            availableWidth = width
            let spacing = (width - itemCountPerLine * collectionViewLayout.itemSize.width) / (itemCountPerLine + 1)
            collectionViewLayout.sectionInset.left = spacing
            collectionViewLayout.sectionInset.right = spacing
            collectionViewLayout.minimumInteritemSpacing = spacing
        }
    }
}

// MARK: - @protocol UICollectionViewDelegate
extension ChatMoreActionView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let section = indexPath.section
        let row = indexPath.row
        if section == 0 {
            itemDataSouce[row].2()
        }
    }
}

// MARK: - @protocol UICollectionViewDataSource
extension ChatMoreActionView: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return itemDataSouce.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ChatMoreActionCollectionViewCell.ts_identifier, for: indexPath) as! ChatMoreActionCollectionViewCell
        
        let item = itemDataSouce[indexPath.row]
        cell.itemButton.setImage(item.iconImage, for: .normal)
        cell.itemLabel.text = item.name
        
        return cell
    }
}

protocol ChatMoreActionViewDelegate: class {
    
    func chatShareMoreViewPhotoTaped()
    
    func chatShareMoreViewCameraTaped()
    
    func chatShareMoreViewFileTaped()
    
    func chatShareMoreViewAudioCallTaped()
}
