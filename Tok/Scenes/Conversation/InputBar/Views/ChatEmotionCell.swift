import UIKit

class ChatEmotionCell: UICollectionViewCell {
    static let ExpressionBundle = Bundle(url: Bundle.main.url(forResource: "Expression", withExtension: "bundle")!)
    static let ExpressionBundleName = "Expression.bundle"
    
    @IBOutlet weak var emotionImageView: UIImageView!
    internal var isDelete: Bool = false
    var emotionModel: EmotionModel? = nil

    override func prepareForReuse() {
        super.prepareForReuse()
        self.emotionImageView.image = nil
        self.emotionModel = nil
    }
    
    func setCellContnet(_ model: EmotionModel? = nil) {
        guard let model = model else {
            self.emotionImageView.image = nil
            return
        }
        self.emotionModel = model
        self.isDelete = false
        if let path = ChatEmotionCell.ExpressionBundle!.path(forResource: model.imageString, ofType:"png") {
            self.emotionImageView.image = UIImage(contentsOfFile: path)
        }
    }
    
    func setDeleteCellContnet() {
        self.emotionModel = nil
        self.isDelete = true
        self.emotionImageView.image = UIImage(named: "EmotionDelete")
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
}

struct EmotionModel {
    var imageString : String!
    var text : String!
    
    init(fromDictionary dictionary: NSDictionary){
        let imageText = dictionary["image"] as! String
        imageString = "\(imageText)@2x"
        text = dictionary["text"] as? String
    }
}



