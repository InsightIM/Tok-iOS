import UIKit

public enum PopupMenuType {
    case defaultWhite //Default
    case dark
}
/**
 箭头方向优先级
 
 当控件超出屏幕时会自动调整成反方向
 */
public enum PopupMenuPriorityDirection : Int {
    case top = 0
    case bottom
    case left
    case right
    case none //不自动调整
}

@objc public protocol PopupMenuDelegate : NSObjectProtocol {
    /// block回调时 非可选
   @objc  func popupMenuDidSelected(index : NSInteger,popupMenu: PopupMenu)
   @objc optional func popupMenuBeganDismiss()
   @objc optional func popupMenuDidDismiss()
   @objc optional func popupMenuBeganShow()
   @objc optional func popupMenudidShow()
}

open class PopupMenu: UIView {
    
    
    /// 点击选中回调
    var didSelectRow : ((NSInteger,String,PopupMenu)->())?

    /**
     圆角半径 Default is 5.0
     */
    public var cornerRadius : CGFloat = 5.0
    
    /**
     自定义圆角 Default is UIRectCorner.allCorners
     
     当自动调整方向时corner会自动转换至镜像方向
     */
    public var rectCorner : UIRectCorner = UIRectCorner.allCorners{
        didSet{
           // updateUI()
        }
    }

    /**
     是否显示阴影 Default is YES
     */
    public var isShowShadow : Bool = true{
        didSet{
            layer.shadowOpacity = isShowShadow == true ? 0.5 : 0
            layer.shadowOffset = CGSize.init(width: 0, height: 0)
            layer.shadowRadius = isShowShadow == true ? 2.0 : 0
        }
    }

    /**
     是否显示灰色覆盖层 Default is YES
     */
    public var showMaskView : Bool = true{
        didSet{
            let blackColor = UIColor.black
            blackColor.withAlphaComponent(0.1)
            menuBackView.backgroundColor = showMaskView == true ? blackColor : UIColor.clear
        }
    }

    /**
     选择菜单项后消失 Default is YES
     */
    public var dismissOnSelected : Bool = true

    /**
     点击菜单外消失  Default is YES
     */
    public var dismissOnTouchOutside : Bool = true

    /**
     设置字体大小 Default is 15
     */
    public var fontSize : CGFloat = 15

    /**
     设置字体颜色 Default is UIColor.black
     */
    public var textColor : UIColor = UIColor.black{
        didSet{
           // tableView.reloadData()
        }
    }

    /**
     设置偏移距离 (>= 0) Default is 0.0
     */
    public var offset : CGFloat = 0.0
    
    /**
     边框宽度 Default is 0.0
     
     设置边框需 > 0
     */
    public var borderWidth : CGFloat = 0.0

    /**
     边框颜色 Default is LightGrayColor
     
     borderWidth <= 0 无效
     */
    public var borderColor : UIColor = UIColor.lightGray
 
    /**
     箭头宽度 Default is 15
     */
    public var arrowWidth : CGFloat = 15
    
    /**
     箭头高度 Default is 10
     */
    public var arrowHeight : CGFloat = 10

    /**
     箭头位置 Default is center
     
     只有箭头优先级是YBPopupMenuPriorityDirectionLeft/YBPopupMenuPriorityDirectionRight/YBPopupMenuPriorityDirectionNone时需要设置
     */
    public var arrowPosition : CGFloat = 0
    
    
    /**
     箭头方向 Default is YBPopupMenuArrowDirectionTop
     */
    public var arrowDirection : PopupMenuArrowDirection = PopupMenuArrowDirection.top{
        didSet{
           // updateUI()
        }
    }
    
    
    /**
     箭头优先方向 Default is YBPopupMenuPriorityDirectionTop
     
     当控件超出屏幕时会自动调整箭头位置
     */
    public var priorityDirection : PopupMenuPriorityDirection = PopupMenuPriorityDirection.top{
        didSet{
            // updateUI()
        }
    }
    
    
    /**
     可见的最大行数 Default is 5;
     */
    public var maxVisibleCount : NSInteger = 5
    
    
    /**
     menu背景色 Default is WhiteColor
     */
    public var backColor : UIColor = UIColor.white
    
    
    /**
     item的高度 Default is 44;
     */
    public var itemHeight : CGFloat = 44{
        didSet{
            tableView.rowHeight = itemHeight
            updateUI()
        }
    }
    
    /**
     设置显示模式 Default is YBPopupMenuTypeDefault
     */
    public var type : PopupMenuType = PopupMenuType.defaultWhite {
        
        didSet{
            switch type {
            case .dark:
                textColor = UIColor.lightGray
                backColor = UIColor.init(red: 0.25, green: 0.27, blue: 0.29, alpha: 1)
                separatorColor = UIColor.lightGray
            default:
                textColor = UIColor.black
                backColor = UIColor.white
                separatorColor = UIColor.lightGray
            }
        }
    }
    
    
    /**
     代理
     */
     weak var delegate : PopupMenuDelegate?
    
    
    // MARK: Private properties
    private var menuBackView : UIView = UIView.init(frame: CGRect.init(x: 0, y: 0, width: screenWidth, height: screenHeight))
    private var relyRect : CGRect = CGRect.zero
    private var minSpace : CGFloat = 10.0
    private var itemWidth : CGFloat = 0{
        didSet{
            updateUI()
        }
    }
    

    override open var frame: CGRect{
        didSet {
            if arrowDirection == .top {
                tableView.frame = CGRect.init(x: borderWidth, y: borderWidth + arrowHeight, width: frame.size.width - borderWidth * 2, height: frame.size.height - arrowHeight)
            }else if arrowDirection == .bottom {
                tableView.frame = CGRect.init(x: borderWidth, y: borderWidth , width: frame.size.width - borderWidth * 2, height: frame.size.height - arrowHeight)
            }else if arrowDirection == .left {
                tableView.frame = CGRect.init(x: borderWidth + arrowHeight, y: borderWidth, width: frame.size.width - borderWidth * 2 - arrowHeight, height: frame.size.height)

            }else if arrowDirection == .right {
                tableView.frame = CGRect.init(x: borderWidth, y: borderWidth , width: frame.size.width - borderWidth * 2 - arrowHeight, height: frame.size.height)
            }else if arrowDirection == .none {
                tableView.frame = CGRect.init(x: borderWidth, y: borderWidth , width: frame.size.width - borderWidth * 2 , height: frame.size.height)
            }
        }
    }
    
    
    var titles = [String]()
    var images = [String]()
    var point : CGPoint = CGPoint.zero
    
    var isCornerChanged : Bool = false
    var isChangeDirection : Bool = false
    var separatorColor : UIColor!
    
    lazy var tableView: UITableView = {
        let tableView = UITableView.init(frame: CGRect.zero, style: UITableView.Style.plain)
        tableView.backgroundColor = UIColor.clear
        tableView.tableFooterView = UIView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        return tableView
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setDefaultSettings()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    func setDefaultSettings() {
        type = PopupMenuType.defaultWhite
        menuBackView.backgroundColor = UIColor.init(red: 0, green: 0, blue: 0, alpha: 0.1)
        menuBackView.alpha = 0
        let tap = UITapGestureRecognizer.init(target: self, action: #selector(touchOutside))
        menuBackView.addGestureRecognizer(tap)
        self.alpha = 0
        backgroundColor = UIColor.clear
        addSubview(tableView)
    }
    
    @objc func touchOutside() {
        if dismissOnTouchOutside == true {
            dismiss()
        }
    }
   
    func dismiss() {
        if let delegate = delegate {
            if delegate.responds(to: #selector(delegate.popupMenuBeganDismiss)){
                delegate.popupMenuBeganDismiss!()
            }
        }
        UIView.animate(withDuration: 0.25, animations: {
            self.layer.setAffineTransform(CGAffineTransform.init(scaleX: 0.1, y: 0.1))
            self.alpha = 0
            self.menuBackView.alpha = 0
        }) { (finished) in
            if let delegate = self.delegate {
                if delegate.responds(to: #selector(delegate.popupMenuDidDismiss)){
                    delegate.popupMenuDidDismiss!()
                }
            }
            self.delegate = nil
            self.removeFromSuperview()
            self.menuBackView.removeFromSuperview()
        }
    }
    
    // MARK: publics methods
    /**
     在指定位置弹出 不推荐使用
     
     @param titles    标题数组  数组里是NSString/NSAttributedString
     @param icons     图标数组  数组里是NSString/UIImage
     @param itemWidth 菜单宽度
     @param delegate  代理
     */
    public static func showAtPoint(point : CGPoint,titles : Array<String>, icons: Array<String>?,menuWidth itemWidth : CGFloat, delegate : PopupMenuDelegate) -> PopupMenu {
        let popupMenu = PopupMenu.init()
        popupMenu.point = point
        popupMenu.titles = titles
        if let icons = icons {
            popupMenu.images = icons
        }
        popupMenu.itemWidth = itemWidth
        popupMenu.delegate = delegate
        popupMenu.show()
        return popupMenu
    }
    
    /**
     在指定位置弹出(推荐方法 delegate,可高度自定义)
     
     @param point          弹出的位置
     @param titles         标题数组  数组里是NSString/NSAttributedString
     @param icons          图标数组  数组里是NSString/UIImage
     @param itemWidth      菜单宽度
     @param delegate  代理
     @param otherSetting   其他设置
     */
    static public func showAtPoint(point : CGPoint,titles : Array<String>, icons: Array<String>?,menuWidth itemWidth : CGFloat,delegate : PopupMenuDelegate,otherSettings : (PopupMenu)->() ) -> PopupMenu {
        let popupMenu = PopupMenu.init()
        popupMenu.point = point
        popupMenu.titles = titles
    
        if let icons = icons {
            popupMenu.images = icons
        }
        popupMenu.itemWidth = itemWidth

        otherSettings(popupMenu)
        popupMenu.delegate = delegate
        popupMenu.updateUI()
        popupMenu.show()
        return popupMenu
    }
    
    
    /**
     在指定位置弹出(推荐方法 block回调)
     
     @param point          弹出的位置
     @param titles         标题数组  数组里是NSString/NSAttributedString
     @param icons          图标数组  数组里是NSString/UIImage
     @param itemWidth      菜单宽度
     @param didSelectRow   点击cell回调block
     @param otherSetting   其他设置
     */
    static public func showAtPoint(point : CGPoint,titles : Array<String>, icons: Array<String>?,menuWidth itemWidth : CGFloat, didSelectRow : @escaping ((NSInteger,String,PopupMenu)->()), otherSettings : (PopupMenu)->() ) -> PopupMenu {
        
        let popupMenu = PopupMenu.init()
        popupMenu.didSelectRow = didSelectRow
        popupMenu.point = point
        popupMenu.titles = titles
        
        if let icons = icons {
            popupMenu.images = icons
        }
        popupMenu.itemWidth = itemWidth
        
        otherSettings(popupMenu)
        popupMenu.updateUI()
        popupMenu.show()
        return popupMenu
    }
    
    /**
     依赖指定view弹出 不推荐使用
     
     @param titles    标题数组  数组里是NSString/NSAttributedString
     @param icons     图标数组  数组里是NSString/UIImage
     @param itemWidth 菜单宽度
     @param delegate  代理
     */
    public static func showRelyOnView(view : UIView,titles : Array<String>, icons: Array<String>?,menuWidth itemWidth : CGFloat, delegate : PopupMenuDelegate ) -> PopupMenu {
        
        let absoluteRect = view.convert(view.bounds, to: mainWindow)
        let relyPoint = CGPoint.init(x: absoluteRect.origin.x + absoluteRect.size.width / 2, y: absoluteRect.origin.y + absoluteRect.size.height)
        
        let popupMenu = PopupMenu.init()
        popupMenu.point = relyPoint
        popupMenu.relyRect = absoluteRect
        popupMenu.titles = titles
        if let icons = icons {
            popupMenu.images = icons
        }
        popupMenu.itemWidth = itemWidth
        popupMenu.delegate = delegate
        popupMenu.updateUI()
        popupMenu.show()
        return popupMenu
    }
    
    /**
     依赖指定view弹出(推荐方法 block回调)
     
     @param titles         标题数组  数组里是NSString/NSAttributedString
     @param icons          图标数组  数组里是NSString/UIImage
     @param itemWidth      菜单宽度
     @param didSelectRow   点击cell回调block
     @param otherSetting   其他设置
     */
    @discardableResult
    public static func showRelyOnView(view : UIView,titles : Array<String>, icons: Array<String>?,menuWidth itemWidth : CGFloat, didSelectRow : @escaping ((NSInteger,String,PopupMenu)->()), otherSettings : (PopupMenu)->()) -> PopupMenu {
        
        let absoluteRect = view.convert(view.bounds, to: mainWindow)
        let relyPoint = CGPoint.init(x: absoluteRect.origin.x + absoluteRect.size.width / 2, y: absoluteRect.origin.y + absoluteRect.size.height/2)
        
        let popupMenu = PopupMenu.init()
        popupMenu.didSelectRow = didSelectRow
        popupMenu.point = relyPoint
        popupMenu.relyRect = absoluteRect
        popupMenu.titles = titles
        if let icons = icons {
            popupMenu.images = icons
        }
        popupMenu.itemWidth = itemWidth
        otherSettings(popupMenu)
        popupMenu.updateUI()
        popupMenu.show()
        return popupMenu
    }
    
    /**
     依赖指定view弹出(推荐方法:delegate,可高度自定义)
     
     @param titles         标题数组  数组里是NSString/NSAttributedString
     @param icons          图标数组  数组里是NSString/UIImage
     @param itemWidth      菜单宽度
     @param delegate  代理
     @param otherSetting   其他设置
     */
    public static func showRelyOnView(view : UIView,titles : Array<String>, icons: Array<String>?,menuWidth itemWidth : CGFloat,delegate : PopupMenuDelegate, otherSettings : (PopupMenu)->()  ) -> PopupMenu {

        let absoluteRect = view.convert(view.bounds, to: mainWindow)
        let relyPoint = CGPoint.init(x: absoluteRect.origin.x + absoluteRect.size.width / 2, y: absoluteRect.origin.y + absoluteRect.size.height/2)

        let popupMenu = PopupMenu.init()
        popupMenu.point = relyPoint
        popupMenu.relyRect = absoluteRect
        popupMenu.titles = titles
        if let icons = icons {
            popupMenu.images = icons
        }
        popupMenu.itemWidth = itemWidth
        otherSettings(popupMenu)
        popupMenu.updateUI()
        popupMenu.delegate = delegate
        popupMenu.show()
        return popupMenu
    }
    
//    MARK: privates methods
    private func show() {
        mainWindow.addSubview(menuBackView)
        mainWindow.addSubview(self)
        let cell : PopupMenuCell = getLastVisibleCell()
        cell.isShowSeparator = false
        if let delegate = delegate {
            if delegate.responds(to: #selector(delegate.popupMenuBeganShow)){
                delegate.popupMenuBeganShow!()
            }
        }
        layer.setAffineTransform(CGAffineTransform.init(scaleX: 0.1, y: 0.1))
        
        UIView.animate(withDuration: 0.25, animations: {
            self.layer.setAffineTransform(CGAffineTransform.init(scaleX: 1.0, y: 1.0))
            self.alpha = 1
            self.menuBackView.alpha = 1
        }) { (finished) in
            if let delegate = self.delegate {
                if delegate.responds(to: #selector(delegate.popupMenudidShow)){
                    delegate.popupMenudidShow!()
                }
            }
        }
    }
    
    func updateUI() {
        var height : CGFloat = 0
        if titles.count > maxVisibleCount {
            height = itemHeight * CGFloat(maxVisibleCount) + borderWidth * 2;
            tableView.bounces = true
        }else{
            height = itemHeight * CGFloat(titles.count) + borderWidth * 2;
            tableView.bounces = false
        }
        isChangeDirection = false
        
        if priorityDirection == .top {
            if point.y + height + arrowHeight > screenHeight - minSpace {
                arrowDirection = PopupMenuArrowDirection.bottom
                isChangeDirection = true
            }else{
                arrowDirection = PopupMenuArrowDirection.top
                isChangeDirection = false
            }
        }else if priorityDirection == .bottom {
            if point.y - height - arrowHeight < minSpace {
                arrowDirection = PopupMenuArrowDirection.top
                isChangeDirection = true
            }else{
                arrowDirection = PopupMenuArrowDirection.bottom
                isChangeDirection = false
            }
        }else if priorityDirection == .left {
            if point.x + itemWidth + arrowHeight > screenWidth - minSpace {
                arrowDirection = PopupMenuArrowDirection.right
                isChangeDirection = true
            }else{
                arrowDirection = PopupMenuArrowDirection.left
                isChangeDirection = false
            }
        }else if priorityDirection == .right {
            if point.x - itemWidth - arrowHeight < minSpace {
                arrowDirection = PopupMenuArrowDirection.left
                isChangeDirection = true
            }else{
                arrowDirection = PopupMenuArrowDirection.right
                isChangeDirection = false
            }
        }else{ // .none
            if point.y + height + arrowHeight > screenHeight - minSpace {
                isChangeDirection = true
            }else{
                isChangeDirection = false
            }
            arrowDirection = PopupMenuArrowDirection.none
        }
        
        setArrowPosition()
        setRelyRect()
        
        if arrowDirection == .top {

            let y =  point.y
            if arrowPosition > itemWidth / 2 {
                frame = CGRect.init(x: screenWidth - minSpace - itemWidth, y:y , width: itemWidth, height: height + arrowHeight)
            }else if arrowPosition < itemWidth / 2 {
                frame = CGRect.init(x: minSpace, y:y , width: itemWidth, height: height + arrowHeight)
            }else{
                frame = CGRect.init(x: point.x - itemWidth / 2, y:y , width: itemWidth, height: height + arrowHeight)
            }
        }else if arrowDirection == .bottom{
            let y = point.y - arrowHeight - height
            if arrowPosition > itemWidth / 2 {
                frame = CGRect.init(x: screenWidth - minSpace - itemWidth, y:y , width: itemWidth, height: height + arrowHeight)
            }else if arrowPosition < itemWidth / 2 {
                frame = CGRect.init(x: minSpace, y:y , width: itemWidth, height: height + arrowHeight)
            }else{
                frame = CGRect.init(x: point.x - itemWidth / 2, y:y , width: itemWidth, height: height + arrowHeight)
            }
        }else if arrowDirection == .left{
            let x = point.x 
            if arrowPosition < itemHeight / 2 {
                frame = CGRect.init(x: x , y:point.y - arrowPosition, width: itemWidth + arrowHeight, height: height )
            }else if arrowPosition > itemHeight / 2 {
                frame = CGRect.init(x: x, y:point.y - arrowPosition, width: itemWidth + arrowHeight, height: height)
            }else{
                frame = CGRect.init(x: x, y:point.y - arrowPosition, width: itemWidth + arrowHeight, height: height)
            }
        }else if arrowDirection == .right{
            let x = isChangeDirection ? point.x - itemWidth - arrowHeight - 2*borderWidth : point.x - itemWidth - arrowHeight - 2*borderWidth
            if arrowPosition < itemHeight / 2 {
                frame = CGRect.init(x: x , y:point.y - arrowPosition, width: itemWidth + arrowHeight, height: height )
            }else if arrowPosition > itemHeight / 2 {
                frame = CGRect.init(x: x-itemWidth/2, y:point.y - arrowPosition, width: itemWidth + arrowHeight, height: height)
            }else{
                frame = CGRect.init(x: x, y:point.y - arrowPosition, width: itemWidth + arrowHeight, height: height)
            }
        }else if arrowDirection == .none{
            
            let y = isChangeDirection ? point.y - arrowHeight - height : point.y + arrowHeight
            if arrowPosition > itemWidth / 2 {
                frame = CGRect.init(x: screenWidth - minSpace - itemWidth, y:y , width: itemWidth, height: height )
            }else if arrowPosition < itemWidth / 2 {
                frame = CGRect.init(x: minSpace, y:y , width: itemWidth, height: height)
            }else{
                frame = CGRect.init(x: point.x - itemWidth / 2, y:y , width: itemWidth, height: height)
            }
        }
        
        setAnchorPoint()
        setOffset()
        tableView.reloadData()
        setNeedsDisplay()
    }
    
    func setArrowPosition() {
        if priorityDirection == .none {
            return
        }
        if arrowDirection == .top || arrowDirection == .bottom {
            if point.x + itemWidth / 2 > screenWidth - minSpace {
                arrowPosition = itemWidth - (screenWidth - minSpace - point.x)
            }else if point.x < itemWidth / 2 + minSpace {
                arrowPosition = point.x - minSpace
            }else{
                arrowPosition = itemWidth / 2
            }
        }else if arrowDirection == .left || arrowDirection == .right {
            
            
        }
    }
    func setRelyRect() {
        if relyRect == CGRect.zero {
            return
        }
        
        if arrowDirection == .top {
            point.y = relyRect.size.height + relyRect.origin.y
        }else if arrowDirection == .bottom {
            point.y = relyRect.origin.y
        }else if arrowDirection == .left {
            point = CGPoint.init(x: relyRect.origin.x + relyRect.size.width, y: relyRect.origin.y + relyRect.size.height / 2)
        }else if arrowDirection == .right {
            point = CGPoint.init(x: relyRect.origin.x + relyRect.size.width, y: relyRect.origin.y + relyRect.size.height / 2)
        }else{ // none
            if isChangeDirection == true {
                point = CGPoint.init(x: relyRect.origin.x + relyRect.size.width/2, y: relyRect.origin.y)
            }else{
                point = CGPoint.init(x: relyRect.origin.x + relyRect.size.width/2, y: relyRect.origin.y + relyRect.size.height )
            }
        }
    }
 
    func setAnchorPoint() {
        if itemWidth == 0 {
            return
        }
        
        var point = CGPoint.init(x: 0.5, y: 0.5)
        if arrowDirection == .top {
            point = CGPoint.init(x: arrowPosition / itemWidth, y: 0)
        }else if arrowDirection == .bottom {
            point = CGPoint.init(x: arrowPosition / itemWidth, y: 1)
        }else if arrowDirection == .left {
            point = CGPoint.init(x: 0 , y: (itemHeight - arrowPosition) / itemHeight)
        }else if arrowDirection == .right {
            point = CGPoint.init(x: 0, y: (itemHeight - arrowPosition) / itemHeight)
        }else if arrowDirection == .none {
            if isChangeDirection == true{
                point = CGPoint.init(x: arrowPosition / itemWidth, y: 1)
            }else{
                point = CGPoint.init(x: arrowPosition / itemWidth, y: 0)
            }
        }
        let originRect = frame
        layer.anchorPoint = point
        frame = originRect
    }

    func setOffset() {
        if itemWidth == 0 {
            return
        }
        
        var originRect = frame
        if arrowDirection == .top {
            originRect.origin.y += offset
        }else if arrowDirection == .bottom {
            originRect.origin.y -= offset
        }else if arrowDirection == .left {
            originRect.origin.y += offset
        }else if arrowDirection == .right {
            originRect.origin.y -= offset
        }
        frame = originRect
    }
    
    override open func draw(_ rect: CGRect) {
        super.draw(rect)

        let bezierPath = PopupMenuPath.bezierPathWithRect(myRect: rect, rectCorner: self.rectCorner, cornerRadius: cornerRadius, borderWidth: borderWidth, borderColor: borderColor, backgroundColor: backColor, arrowWidth: arrowWidth, arrowHeight: arrowHeight, myArrowPosition: arrowPosition, arrowDirection: arrowDirection)
        bezierPath.fill()
        bezierPath.stroke()
    }
}

// MARK: -ScrollViewDelegate
extension PopupMenu {
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        let cell : PopupMenuCell = getLastVisibleCell()
        cell.isShowSeparator = true
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let cell : PopupMenuCell = getLastVisibleCell()
        cell.isShowSeparator = false
    }
    
    func getLastVisibleCell()-> PopupMenuCell {
        var indexPaths = tableView.indexPathsForVisibleRows
        indexPaths = indexPaths?.sorted{ (obj1, obj2) -> Bool in
            return obj1.row < obj2.row
        }
        let indexPath = indexPaths?.last
        return tableView.cellForRow(at: indexPath!) as! PopupMenuCell
    }
}
// MARK: UITableViewDelegate & UITableViewDataSource
fileprivate let identifier = "popupMenu"
extension PopupMenu : UITableViewDelegate,UITableViewDataSource {
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return titles.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: identifier) as? PopupMenuCell
        if cell == nil {
            cell = PopupMenuCell.init(style: UITableViewCell.CellStyle.value1, reuseIdentifier: identifier)
            cell?.textLabel?.numberOfLines = 0
        }
        cell!.backgroundColor = UIColor.clear
        cell!.textLabel?.textColor = textColor
        cell!.textLabel?.font = UIFont.systemFont(ofSize: fontSize)
        cell!.textLabel?.text = titles[indexPath.row]
        
        if let separatorColor = separatorColor {
            cell!.separatorColor = separatorColor
        }
        
        if images.count >= indexPath.row + 1 {
            cell!.imageView?.image = UIImage.init(named: images[indexPath.row])
        }else{
            cell!.imageView?.image = nil
        }
        
        return cell!
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if didSelectRow != nil {
            didSelectRow!(indexPath.row,titles[indexPath.row],self)
            dismiss()
        }
        if let delegate = delegate {
            delegate.popupMenuDidSelected(index: indexPath.row, popupMenu: self)
            dismiss()
        }
    }
    
}

