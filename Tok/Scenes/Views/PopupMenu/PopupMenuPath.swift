import UIKit

public enum PopupMenuArrowDirection : Int {
    case top = 0 //箭头朝上
    case bottom
    case left
    case right
    case none
}

class PopupMenuPath {
    
    public static func maskLayerWithRect(rect : CGRect,
                           rectCorner : UIRectCorner,
                           cornerRadius : CGFloat,
                           arrowWidth : CGFloat,
                           arrowHeight : CGFloat,
                           arrowPosition : CGFloat,
                           arrowDirection : PopupMenuArrowDirection ) -> CAShapeLayer
    {
        let shapeLayer = CAShapeLayer.init()
        shapeLayer.path = bezierPathWithRect(myRect: rect, rectCorner: rectCorner, cornerRadius: cornerRadius, borderWidth: 0, borderColor: nil, backgroundColor: nil, arrowWidth: arrowWidth, arrowHeight: arrowHeight, myArrowPosition: arrowPosition, arrowDirection: arrowDirection).cgPath
        return shapeLayer
    }
    
    public static  func bezierPathWithRect(myRect : CGRect,
                            rectCorner : UIRectCorner,
                            cornerRadius : CGFloat,
                            borderWidth : CGFloat,
                            borderColor : UIColor?,
                            backgroundColor : UIColor?,
                            arrowWidth : CGFloat,
                            arrowHeight : CGFloat,
                            myArrowPosition : CGFloat,
                            arrowDirection : PopupMenuArrowDirection ) -> UIBezierPath
    {
        let bezierPath = UIBezierPath.init()
        
        if let borderColor = borderColor {
            borderColor.setStroke()
        }
        if let backgroundColor = backgroundColor {
            backgroundColor.setFill()
        }
        bezierPath.lineWidth = borderWidth
        
        let rect = CGRect.init(x: borderWidth / 2, y: borderWidth / 2, width: rectWidth(myRect) - borderWidth, height:rectHeight(myRect) - borderWidth)
        
        var topRightRadius : CGFloat = 0
        var topLeftRadius : CGFloat = 0
        var bottomRightRadius : CGFloat = 0
        var bottomLeftRadius : CGFloat = 0
        
        var topRightArcCenter : CGPoint = CGPoint.zero
        var topLeftArcCenter : CGPoint = CGPoint.zero
        var bottomRightArcCenter : CGPoint = CGPoint.zero
        var bottomLeftArcCenter : CGPoint = CGPoint.zero
        
        if rectCorner.contains(UIRectCorner.topLeft) {
            topLeftRadius = cornerRadius
        }
        if rectCorner.contains(UIRectCorner.topRight) {
            topRightRadius = cornerRadius
        }
        if rectCorner.contains(UIRectCorner.bottomLeft) {
            bottomLeftRadius = cornerRadius
        }
        if rectCorner.contains(UIRectCorner.bottomRight) {
            bottomRightRadius = cornerRadius
        }

        
        if arrowDirection == .top {
            topLeftArcCenter = CGPoint.init(x: topLeftRadius + rectX(rect), y: arrowHeight + topLeftRadius + rectX(rect))
            topRightArcCenter = CGPoint.init(x: rectWidth(rect) - topRightRadius + rectX(rect), y: arrowHeight + topRightRadius + rectX(rect))
            bottomLeftArcCenter = CGPoint.init(x: bottomLeftRadius + rectX(rect), y: rectHeight(rect) - bottomLeftRadius + rectX(rect))
            bottomRightArcCenter = CGPoint.init(x: rectWidth(rect) - bottomRightRadius + rectX(rect), y: rectHeight(rect) - bottomRightRadius + rectX(rect))
            var arrowPosition : CGFloat = 0
            if myArrowPosition < topLeftRadius + arrowWidth / 2 {
                arrowPosition = topLeftRadius + arrowWidth / 2
            }else if myArrowPosition > rectWidth(rect) - topRightRadius - arrowWidth / 2 {
                arrowPosition = rectWidth(rect) - topRightRadius - arrowWidth / 2
            }else{
                arrowPosition = myArrowPosition
            }
            
            bezierPath.move(to: CGPoint.init(x: arrowPosition - arrowWidth / 2, y: arrowHeight + rectX(rect)))
            bezierPath.addLine(to: CGPoint.init(x: arrowPosition, y: rectTop(rect) + rectX(rect)))
            bezierPath.addLine(to: CGPoint.init(x: arrowPosition + arrowWidth / 2, y: arrowHeight + rectX(rect)))
            bezierPath.addLine(to: CGPoint.init(x: rectWidth(rect) - topRightRadius, y: arrowHeight + rectX(rect)))
            bezierPath.addArc(withCenter: topRightArcCenter, radius: topRightRadius, startAngle: CGFloat.pi * 3 / 2, endAngle: CGFloat.pi * 2, clockwise: true)
            bezierPath.addLine(to: CGPoint.init(x: rectWidth(rect) + rectX(rect), y: rectHeight(rect) - bottomRightRadius - rectX(rect)))
            bezierPath.addArc(withCenter: bottomRightArcCenter, radius: bottomRightRadius, startAngle: 0, endAngle: CGFloat.pi*0.5, clockwise: true)
            bezierPath.addLine(to: CGPoint.init(x: bottomLeftRadius + rectX(rect), y: rectHeight(rect) + rectX(rect)))
            
            bezierPath.addArc(withCenter: bottomLeftArcCenter, radius: bottomLeftRadius, startAngle: CGFloat.pi*0.5, endAngle: CGFloat.pi, clockwise: true)
            bezierPath.addLine(to: CGPoint.init(x: rectX(rect), y: arrowHeight + topLeftRadius + rectX(rect)))
            bezierPath.addArc(withCenter: topLeftArcCenter, radius: topLeftRadius, startAngle: CGFloat.pi, endAngle: CGFloat.pi * 3 / 2, clockwise: true)
        }else if arrowDirection == .bottom {// 箭头朝下
            
            topLeftArcCenter = CGPoint.init(x: topLeftRadius + rectX(rect), y: topLeftRadius + rectX(rect))
            topRightArcCenter = CGPoint.init(x: rectWidth(rect) - topRightRadius + rectX(rect), y: topRightRadius + rectX(rect))
            bottomLeftArcCenter = CGPoint.init(x: bottomLeftRadius + rectX(rect), y: rectHeight(rect) - bottomLeftRadius + rectX(rect) - arrowHeight)
            bottomRightArcCenter = CGPoint.init(x: rectWidth(rect) - bottomRightRadius + rectX(rect), y: rectHeight(rect) - bottomRightRadius + rectX(rect) - arrowHeight)
            var arrowPosition : CGFloat = 0
            if myArrowPosition < bottomLeftRadius + arrowWidth / 2 {
                arrowPosition = bottomLeftRadius + arrowWidth / 2
            }else if arrowPosition > rectWidth(rect) - bottomRightRadius - arrowWidth / 2 {
                arrowPosition = rectWidth(rect) - bottomRightRadius - arrowWidth / 2
            }else{
                arrowPosition = myArrowPosition
            }
            
            bezierPath.move(to: CGPoint.init(x: arrowPosition + arrowWidth / 2, y: rectHeight(rect) - arrowHeight + rectX(rect)))
            bezierPath.addLine(to: CGPoint.init(x: arrowPosition, y: rectHeight(rect) + rectX(rect)))
            bezierPath.addLine(to: CGPoint.init(x: arrowPosition - arrowWidth / 2, y: rectHeight(rect) - arrowHeight + rectX(rect)))
            bezierPath.addLine(to: CGPoint.init(x: bottomLeftRadius + rectX(rect), y: rectHeight(rect) - arrowHeight + rectX(rect)))
            bezierPath.addArc(withCenter: bottomLeftArcCenter, radius: bottomLeftRadius, startAngle: CGFloat.pi / 2, endAngle: CGFloat.pi, clockwise: true)
            bezierPath.addLine(to: CGPoint.init(x: rectX(rect), y: topLeftRadius + rectX(rect)))
            bezierPath.addArc(withCenter: topLeftArcCenter, radius: topLeftRadius, startAngle: CGFloat.pi, endAngle: CGFloat.pi * 3 / 2, clockwise: true)
            bezierPath.addLine(to: CGPoint.init(x: rectWidth(rect) - topRightRadius + rectX(rect), y: rectX(rect)))
            bezierPath.addArc(withCenter: topRightArcCenter, radius: topRightRadius, startAngle: CGFloat.pi * 3 / 2, endAngle: CGFloat.pi * 2, clockwise: true)
            bezierPath.addLine(to: CGPoint.init(x: rectWidth(rect) + rectX(rect), y: rectHeight(rect) - bottomRightRadius - rectX(rect) - arrowHeight))
            bezierPath.addArc(withCenter: bottomRightArcCenter, radius: bottomRightRadius, startAngle: 0, endAngle: CGFloat.pi / 2, clockwise: true)
        }else if arrowDirection == .left { // 箭头朝左
            
            topLeftArcCenter = CGPoint.init(x: topLeftRadius + rectX(rect) + arrowHeight, y: topLeftRadius + rectX(rect))
            topRightArcCenter = CGPoint.init(x: rectWidth(rect) - topRightRadius + rectX(rect), y: topRightRadius + rectX(rect))
            bottomLeftArcCenter = CGPoint.init(x: bottomLeftRadius + rectX(rect) + arrowHeight, y: rectHeight(rect) - bottomLeftRadius + rectX(rect))
            bottomRightArcCenter = CGPoint.init(x: rectWidth(rect) - bottomRightRadius + rectX(rect), y: rectHeight(rect) - bottomRightRadius + rectX(rect))
            
            var arrowPosition : CGFloat = 0
            if myArrowPosition < topLeftRadius + arrowWidth / 2 {
                arrowPosition = topLeftRadius + arrowWidth / 2
            }else if arrowPosition > rectHeight(rect) - bottomLeftRadius - arrowWidth / 2 {
                arrowPosition = rectHeight(rect) - bottomLeftRadius - arrowWidth / 2
            }else{
                arrowPosition = myArrowPosition
            }
            
            bezierPath.move(to: CGPoint.init(x: arrowHeight + rectX(rect), y: arrowPosition + arrowWidth / 2))
            bezierPath.addLine(to: CGPoint.init(x: rectX(rect), y: arrowPosition))
            bezierPath.addLine(to: CGPoint.init(x: arrowHeight + rectX(rect), y: arrowPosition - arrowWidth / 2))
            bezierPath.addLine(to: CGPoint.init(x: arrowHeight + rectX(rect), y: topLeftRadius + rectX(rect)))
            bezierPath.addArc(withCenter: topLeftArcCenter, radius: topLeftRadius, startAngle: CGFloat.pi, endAngle: CGFloat.pi*3/2, clockwise: true)
            bezierPath.addLine(to: CGPoint.init(x: rectWidth(rect) - topRightRadius, y: rectX(rect)))
            bezierPath.addArc(withCenter: topRightArcCenter, radius: topRightRadius, startAngle: CGFloat.pi*3/2, endAngle: CGFloat.pi*2, clockwise: true)
            bezierPath.addLine(to: CGPoint.init(x: rectWidth(rect) + rectX(rect), y: rectHeight(rect) - bottomRightRadius - rectX(rect)))
            bezierPath.addArc(withCenter: bottomRightArcCenter, radius: bottomRightRadius, startAngle: 0, endAngle: CGFloat.pi*0.5, clockwise: true)
            bezierPath.addLine(to: CGPoint.init(x: arrowHeight + bottomLeftRadius + rectX(rect), y: rectHeight(rect) + rectX(rect)))
            bezierPath.addArc(withCenter: bottomLeftArcCenter, radius: bottomLeftRadius, startAngle: CGFloat.pi*0.5, endAngle: CGFloat.pi, clockwise: true)
        }else if arrowDirection == .right{ // 箭头朝右
            
            topLeftArcCenter = CGPoint.init(x: topLeftRadius + rectX(rect), y: topLeftRadius + rectX(rect))
            topRightArcCenter = CGPoint.init(x: rectWidth(rect) - topRightRadius + rectX(rect) - arrowHeight, y: topRightRadius + rectX(rect))
            bottomLeftArcCenter = CGPoint.init(x: bottomLeftRadius + rectX(rect) , y: rectHeight(rect) - bottomLeftRadius + rectX(rect))
            bottomRightArcCenter = CGPoint.init(x: rectWidth(rect) - bottomRightRadius + rectX(rect) - arrowHeight, y: rectHeight(rect) - bottomRightRadius + rectX(rect))
            
            var arrowPosition : CGFloat = 0
            if myArrowPosition < topRightRadius + arrowWidth / 2 {
                arrowPosition = topRightRadius + arrowWidth / 2
            }else if arrowPosition > rectHeight(rect) - bottomRightRadius - arrowWidth / 2 {
                arrowPosition = rectHeight(rect) - bottomRightRadius - arrowWidth / 2
            }else{
                arrowPosition = myArrowPosition
            }
            
            bezierPath.move(to: CGPoint.init(x: rectWidth(rect) - arrowHeight + rectX(rect), y: arrowPosition - arrowWidth / 2))
            bezierPath.addLine(to: CGPoint.init(x: rectWidth(rect) + rectX(rect), y: arrowPosition))
            bezierPath.addLine(to: CGPoint.init(x: rectWidth(rect) - arrowHeight + rectX(rect), y: arrowPosition + arrowWidth / 2))
            
            bezierPath.addLine(to: CGPoint.init(x: rectWidth(rect) - arrowHeight + rectX(rect), y: rectHeight(rect) - bottomRightRadius - rectX(rect)))
            bezierPath.addArc(withCenter: bottomRightArcCenter, radius: bottomRightRadius, startAngle: 0, endAngle: CGFloat.pi/2, clockwise: true)
            bezierPath.addLine(to: CGPoint.init(x: bottomLeftRadius + rectX(rect), y: rectHeight(rect) + rectX(rect)))
            bezierPath.addArc(withCenter: bottomLeftArcCenter, radius: bottomLeftRadius, startAngle: CGFloat.pi/2, endAngle: CGFloat.pi, clockwise: true)
            bezierPath.addLine(to: CGPoint.init(x: rectX(rect), y: arrowHeight + topLeftRadius + rectX(rect)))
            bezierPath.addArc(withCenter: topLeftArcCenter, radius: topLeftRadius, startAngle: CGFloat.pi, endAngle: CGFloat.pi*0.5*3, clockwise: true)
            bezierPath.addLine(to: CGPoint.init(x: rectWidth(rect) - topRightRadius + rectX(rect) - arrowHeight, y: rectX(rect)))
            bezierPath.addArc(withCenter: topRightArcCenter, radius: topRightRadius, startAngle: CGFloat.pi*0.5*3, endAngle: CGFloat.pi*2, clockwise: true)
        }else if arrowDirection == .none{ // 无箭头
            
            topLeftArcCenter = CGPoint.init(x: topLeftRadius + rectX(rect), y: topLeftRadius + rectX(rect))
            topRightArcCenter = CGPoint.init(x: rectWidth(rect) - topRightRadius + rectX(rect), y: topRightRadius + rectX(rect))
            bottomLeftArcCenter = CGPoint.init(x: bottomLeftRadius + rectX(rect) , y: rectHeight(rect) - bottomLeftRadius + rectX(rect))
            bottomRightArcCenter = CGPoint.init(x: rectWidth(rect) - bottomRightRadius + rectX(rect), y: rectHeight(rect) - bottomRightRadius + rectX(rect))
            
            
            bezierPath.move(to: CGPoint.init(x: topLeftRadius + rectX(rect), y: rectX(rect)))
            bezierPath.addLine(to: CGPoint.init(x: rectWidth(rect) - topRightRadius, y: rectX(rect)))
 
            bezierPath.addArc(withCenter: topRightArcCenter, radius: topRightRadius, startAngle: CGFloat.pi*0.5*3, endAngle: CGFloat.pi*2, clockwise: true)
            
            bezierPath.addLine(to: CGPoint.init(x: rectWidth(rect) + rectX(rect), y: rectHeight(rect) - bottomRightRadius - rectX(rect)))
            
            bezierPath.addArc(withCenter: bottomRightArcCenter, radius: bottomRightRadius, startAngle: 0, endAngle: CGFloat.pi/2, clockwise: true)
            
            bezierPath.addLine(to: CGPoint.init(x: bottomLeftRadius + rectX(rect), y: rectHeight(rect) + rectX(rect)))
            
            bezierPath.addArc(withCenter: bottomLeftArcCenter, radius: bottomLeftRadius, startAngle: CGFloat.pi/2, endAngle: CGFloat.pi, clockwise: true)
            
            bezierPath.addLine(to: CGPoint.init(x: rectX(rect) , y: arrowHeight + topLeftRadius + rectX(rect)))
            bezierPath.addArc(withCenter: topLeftArcCenter, radius: topLeftRadius, startAngle: CGFloat.pi, endAngle: CGFloat.pi*3/2, clockwise: true)
        }
        bezierPath.close()
        return bezierPath
    }

}
