import UIKit

class ChatMoreActionCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var itemButton: UIButton!
    @IBOutlet weak var itemLabel: UILabel!
    
    override var isHighlighted: Bool {
        didSet {
            if isHighlighted {
                itemButton.ts_setBackgroundColor(UIColor("#F5F6FA"), forState: .normal)
            } else {
                itemButton.ts_setBackgroundColor(UIColor("#FFFFFF"), forState: .normal)
            }
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        
        itemButton.layer.masksToBounds = true
        itemButton.layer.borderColor = UIColor("#DCDCDD").cgColor
        itemButton.layer.borderWidth = 0.5
        itemButton.ts_setBackgroundColor(UIColor("#FFFFFF"), forState: .normal)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        itemButton.layer.cornerRadius = itemButton.bounds.width / 2.0
    }
}
