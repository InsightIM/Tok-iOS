//
//  ProgressButton.swift
//  Tok
//
//  Created by Bryce on 2019/4/11.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import SnapKit
import CoreGraphics

final class ProgressButton: UIControl {
    
    // MARK: Properties
    
    var circleViewLineWidth: CGFloat = 1 {
        didSet {
            progressCircleView.lineWidth = circleViewLineWidth
            trackCircleView.lineWidth = circleViewLineWidth
        }
    }
    
    let stopView: StopView = {
        let view = StopView()
        view.isUserInteractionEnabled = false
        return view
    }()
    
    lazy var trackCircleView: CircleView = {
        let circleView = CircleView()
        circleView.lineWidth = circleViewLineWidth
        circleView.isUserInteractionEnabled = false
        return circleView
    }()
    
    lazy var progressCircleView: ProgressCircleView = {
        let view = ProgressCircleView()
        view.lineWidth = circleViewLineWidth
        view.isUserInteractionEnabled = false
        return view
    }()
    
    var progress: CGFloat = 0 {
        didSet {
            if progress < 0 {
                progress = 0
            } else if progress > 1 {
                progress = 1
            }
            progressCircleView.progress = progress
        }
    }
    
    override var isHighlighted: Bool {
        didSet {
            updateColors()
        }
    }
    
    // MARK: Initializers
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    // MARK: Helper methods
    
    private func commonInit() {
        backgroundColor = .clear
        
        addSubview(trackCircleView)
        trackCircleView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        addSubview(progressCircleView)
        progressCircleView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        addSubview(stopView)
        stopView.snp.makeConstraints { (make) in
            make.center.equalToSuperview()
            make.width.equalTo(stopView.snp.height)
            make.height.equalToSuperview().multipliedBy(0.4)
        }
        
        progressCircleView.progress = 0
        updateColors()
    }
    
    private func updateColors() {
        trackCircleView.circleColor = .white
        progressCircleView.circleColor = .tokBlue
        stopView.lineColor = .white
    }
}

class StopView: UIView {
    
    var lineColor: UIColor = .white {
        didSet {
            line1.strokeColor = lineColor.cgColor
            line2.strokeColor = lineColor.cgColor
        }
    }
    
    let line1 = CAShapeLayer()
    let line2 = CAShapeLayer()
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    override func draw(_ rect: CGRect) {
        let topPath = UIBezierPath()
        topPath.move(to: CGPoint(x: frame.width, y: 0.0))
        topPath.addLine(to: CGPoint(x: 0.0, y: frame.size.height))
        
        let bottomPath = UIBezierPath()
        bottomPath.move(to: CGPoint(x: 0.0, y: 0.0))
        bottomPath.addLine(to: CGPoint(x: frame.width, y: frame.size.height))
        
        line1.path = topPath.cgPath
        line2.path = bottomPath.cgPath
        
        for sublayer in [line1, line2] {
            sublayer.fillColor = nil
            sublayer.strokeColor = lineColor.cgColor
            sublayer.lineWidth = 1
            sublayer.miterLimit = 1
            sublayer.lineCap = CAShapeLayerLineCap.square
            sublayer.masksToBounds = true
            sublayer.frame = bounds
            
            layer.addSublayer(sublayer)
        }
    }
}

fileprivate enum Color {
    
    enum Gray {
        static let light = UIColor(red: 245.0 / 255.0, green: 244.0 / 255.0, blue: 249.0 / 255.0, alpha: 1)
        static let medium = UIColor(red: 238.0 / 255.0, green: 239.0 / 255.0, blue: 245.0 / 255.0, alpha: 1)
        static let dark = UIColor(red: 229.0 / 255.0, green: 229.0 / 255.0, blue: 233.0 / 255.0, alpha: 1)
    }
    
    enum Blue {
        static let light = UIColor(red: 199.0 / 255.0, green: 222 / 255.0, blue: 243 / 255.0, alpha: 1)
        static let medium = UIColor(red: 9.0 / 255.0, green: 111.0 / 255.0, blue: 227.0 / 255.0, alpha: 1)
    }
    
}
