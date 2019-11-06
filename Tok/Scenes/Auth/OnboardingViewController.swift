//
//  OnboardingViewController.swift
//  Tok
//
//  Created by Bryce on 2019/2/3.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import Device

class OnboardingPageView: UIView {
    lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 28, weight: .medium)
        label.textColor = .tokBlack
        label.numberOfLines = 2
        label.adjustsFontSizeToFitWidth = true
        return label
    }()
    
    lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 15, weight: .light)
        label.textColor = .tokBlack
        label.numberOfLines = 3
        label.adjustsFontSizeToFitWidth = true
        return label
    }()
    
    lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(imageView)
        imageView.snp.makeConstraints { (make) in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().multipliedBy(Device.size() > Size.screen4_7Inch ? 1.0 : 1.2)
            make.size.equalTo(CGSize(width: 211, height: 278))
        }
        
        addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints { (make) in
            make.left.greaterThanOrEqualTo(10)
            make.right.lessThanOrEqualTo(-10)
            
            var offset = -40
            if Device.size() > Size.screen5_5Inch {
                offset = -100
            } else if Device.size() == Size.screen5_5Inch || Device.size() == Size.screen4_7Inch  {
                offset = -70
            }
            make.bottom.equalTo(imageView.snp.top).offset(offset)
            make.centerX.equalToSuperview()
        }
        
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { (make) in
            make.left.greaterThanOrEqualTo(10)
            make.right.lessThanOrEqualTo(-10)
            make.bottom.equalTo(subtitleLabel.snp.top).offset(-8)
            make.centerX.equalToSuperview()
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // scale animate
    func scaleAnimate() {
        UIView.animate(withDuration: 0.45,
                       delay: 0.0,
                       usingSpringWithDamping: 0.7,
                       initialSpringVelocity: 4.0,
                       options: .curveEaseIn,
                       animations: { [weak self] in
                        self?.imageView.transform = .identity
                        self?.imageView.alpha = 1.0
        })
    }
    
    // view disappear
    func disappear() {
        imageView.transform = CGAffineTransform(scaleX: 0, y: 0)
        imageView.alpha = 0.0
    }
    
    // view translation
    func translation(scale: CGFloat) {
        titleLabel.transform = CGAffineTransform(translationX: -100 * scale, y: 0)
        subtitleLabel.transform = CGAffineTransform(translationX: -240 * scale, y: 0)
        imageView.transform = CGAffineTransform(translationX: -240 * scale, y: 0)
    }
}

class OnboardingViewController: BaseViewController {
    
    lazy var pageControl: UIPageControl = {
        let pageControl = UIPageControl()
        pageControl.pageIndicatorTintColor = UIColor("#D8D8D8")
        pageControl.currentPageIndicatorTintColor = .tokBlue
        return pageControl
    }()
    
    lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.isPagingEnabled = true
        scrollView.delegate = self
        scrollView.bounces = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()
    
    lazy var welcomeButton: UIButton = {
        let btn = UIButton()
        btn.alpha = 0
        btn.fcStyle(title: NSLocalizedString("Welcome", comment: "").uppercased())
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        return btn
    }()
    
    lazy var firstPageView: OnboardingPageView = {
        let pageView = OnboardingPageView()
        pageView.titleLabel.text = NSLocalizedString("Do not require Phone number", comment: "")
        pageView.subtitleLabel.text = NSLocalizedString("Automatically generate random super-long ID, does not associate any real-name information", comment: "")
        pageView.imageView.image = UIImage(named: "Guide1")
        return pageView
    }()
    
    lazy var secondPageView: OnboardingPageView = {
        let pageView = OnboardingPageView()
        pageView.titleLabel.text = NSLocalizedString("Invisible IP", comment: "")
        pageView.subtitleLabel.text = NSLocalizedString("Hidden IP address by onion routing, unable to track your location", comment: "")
        pageView.imageView.image = UIImage(named: "Guide2")
        return pageView
    }()
    
    lazy var thirdPageView: OnboardingPageView = {
        let pageView = OnboardingPageView()
        pageView.titleLabel.text = NSLocalizedString("Peer-to-Peer encrypted message", comment: "")
        pageView.subtitleLabel.text = NSLocalizedString("Automatically generates super-long key, it takes 9.9 billions years to violently crack-copy version", comment: "")
        pageView.imageView.image = UIImage(named: "Guide3")
        return pageView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupViews()
    }
    
    var views: [OnboardingPageView] {
        return  [firstPageView, secondPageView, thirdPageView]
    }
    
    func setupViews() {
        
        view.backgroundColor = UIColor.white
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        let contentView = UIView()
        scrollView.addSubview(contentView)
        contentView.snp.makeConstraints { (make) in
            make.edges.equalTo(scrollView)
            make.height.equalTo(scrollView)
        }
        
        var lastView: UIView?
        for stepView in views {
            
            contentView.addSubview(stepView)
            
            stepView.snp.makeConstraints { (make) in
                make.top.equalToSuperview()
                make.width.equalTo(self.view)
                make.height.equalToSuperview()
                if let lastView = lastView {
                    make.left.equalTo(lastView.snp.right)
                } else {
                    make.left.equalTo(contentView)
                }
            }
            
            lastView = stepView
        }
        
        contentView.snp.makeConstraints({ (make) in
            make.right.equalTo(lastView!)
        })
        
        // MARK: - 指示器
        view.addSubview(pageControl)
        pageControl.snp.makeConstraints { (make) in
            make.width.equalTo(52)
            make.centerX.equalToSuperview()
            make.bottom.equalTo(self.view.safeArea.bottom).offset(-40)
        }
        pageControl.numberOfPages = views.count
        
        view.addSubview(welcomeButton)
        welcomeButton.snp.makeConstraints { (make) in
            make.left.equalTo(20)
            make.right.equalTo(-20)
            make.height.equalTo(50)
            make.centerY.equalTo(pageControl)
        }
    }

}

extension OnboardingViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
        let pageWidth = scrollView.bounds.width
        let pageFraction = scrollView.contentOffset.x / pageWidth
        let page = Int(Darwin.round(pageFraction))
        pageControl.currentPage = page
        
        if pageFraction > 1 {
            pageControl.transform = CGAffineTransform(translationX: pageWidth - scrollView.contentOffset.x, y: 0)
        }
        
        let scale = pageFraction - CGFloat(page)
        views[page].translation(scale: scale)
        
        if page == 2 {
            UIView.animate(withDuration: 0.25) {
                self.pageControl.alpha = 0
                self.welcomeButton.alpha = 1
            }
        } else {
            self.pageControl.alpha = 1
            self.welcomeButton.alpha = 0
        }
    }
}
