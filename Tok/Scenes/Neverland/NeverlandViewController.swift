//
//  NeverlandViewController.swift
//  Tok
//
//  Created by Bryce on 2019/6/29.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import Lottie
import RxSwift
import RxCocoa
import Device

class NeverlandViewController: BaseViewController {
    enum ViewState {
        case `default`
        case initital
        case loading
        case timeout
        case list
    }
    
    private let disposeBag = DisposeBag()
    private var viewState: ViewState = .default {
        didSet {
            guard viewState != oldValue else {
                return
            }
            
            updateButtons()
            
            switch viewState {
            case .initital:
                startEarthAnimation()
            case .loading:
                startSolarSystemAnimation()
            case .timeout:
                stopSolarSystemAnimation()
            case .list:
                showResultList()
            case .default:
                break
            }
        }
    }
    
    lazy var marqueeView: JXMarqueeView = {
        let marqueeView = JXMarqueeView()
        marqueeView.contentView = PoetryView()
        return marqueeView
    }()
    
    lazy var starsView: AnimationView = {
        let view = AnimationView(name: "stars")
        view.loopMode = .loop
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    lazy var solarView: AnimationView = {
        let view = AnimationView(name: "solar")
        view.loopMode = .loop
        view.contentMode = .scaleAspectFit
        view.alpha = 0
        return view
    }()
    
    lazy var tryStealthButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(NSLocalizedString("Don't want to be seen? Try Stealth Mod >", comment: ""), for: .normal)
        button.setTitleColor(.tokDarkBlue, for: .normal)
        button.setTitleColor(UIColor.tokDarkBlue.withAlphaComponent(0.5), for: .highlighted)
        button.alpha = 0
        button.addTarget(self, action: #selector(self.didClickTryStealth), for: .touchUpInside)
        return button
    }()
    
    lazy var retryButton: UIButton = {
        let button = UIButton(type: .system)
        button.isHidden = true
        button.setTitle(NSLocalizedString("The request timed out and try again >", comment: ""), for: .normal)
        button.setTitleColor(.tokDarkBlue, for: .normal)
        button.setTitleColor(UIColor.tokDarkBlue.withAlphaComponent(0.5), for: .highlighted)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 17)
        button.addTarget(self, action: #selector(self.didClickDiscover), for: .touchUpInside)
        return button
    }()
    
    lazy var loadingButton: UIButton = {
        let button = UIButton()
        button.isUserInteractionEnabled = false
        button.isHidden = true
        button.setTitle(NSLocalizedString("Discovering...", comment: ""), for: .normal)
        button.setTitleColor(.tokDarkBlue, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 17)
        return button
    }()
    
    lazy var discoverButton: UIButton = {
        let button = UIButton()
        button.fcStyle(title: NSLocalizedString("Discover", comment: ""))
        button.addTarget(self, action: #selector(self.didClickDiscover), for: .touchUpInside)
        button.alpha = 0
        return button
    }()
    
    lazy var backButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(named: "Back"), for: .normal)
        button.addTarget(self, action: #selector(self.goBack), for: .touchUpInside)
        return button
    }()
    
    lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        label.textAlignment = .center
        label.textColor = .white
        label.text = NSLocalizedString("Neverland", comment: "")
        return label
    }()
    
    lazy var overlayView: UIView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "MarqueeMarker")
        imageView.contentMode = .scaleAspectFill
        return imageView
    }()
    
    lazy var earthView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "Earth")
        imageView.contentMode = .scaleAspectFit
        imageView.alpha = 0
        return imageView
    }()
    
    private var loadStrangers = [Stranger]()
    
    private let findFriendService: FindFriendService
    init(messageService: MessageService) {
        findFriendService = FindFriendService(messageService: messageService)
        super.init()
        hidesBottomBarWhenPushed = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = ""
        view.backgroundColor = UIColor("#04060D")
        
        view.addSubview(solarView)
        view.addSubview(starsView)
        view.addSubview(earthView)
        view.addSubview(tryStealthButton)
        view.addSubview(loadingButton)
        view.addSubview(retryButton)
        view.addSubview(discoverButton)
        view.addSubview(marqueeView)
        view.addSubview(backButton)
        view.addSubview(titleLabel)
        marqueeView.addSubview(overlayView)
        
        overlayView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        solarView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        starsView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        earthView.snp.makeConstraints { (make) in
            make.size.equalTo(48)
            make.center.equalToSuperview()
        }
        
        tryStealthButton.snp.makeConstraints { (make) in
            make.bottom.equalTo(self.view.safeArea.bottom).offset(-50)
            make.leading.equalTo(16)
            make.trailing.equalTo(-16)
        }
        
        loadingButton.snp.makeConstraints { (make) in
            make.size.equalTo(tryStealthButton)
            make.center.equalTo(tryStealthButton)
        }
        
        retryButton.snp.makeConstraints { (make) in
            make.size.equalTo(tryStealthButton)
            make.center.equalTo(tryStealthButton)
        }
        
        discoverButton.snp.makeConstraints { (make) in
            make.leading.equalTo(16)
            make.trailing.equalTo(-16)
            make.height.equalTo(48)
            make.bottom.equalTo(tryStealthButton.snp.top).offset(-40)
        }
        
        backButton.snp.makeConstraints { (make) in
            make.leading.equalTo(16)
            make.top.equalTo(self.view.safeArea.top).offset(10)
            make.size.equalTo(CGSize(width: 24, height: 24))
        }
        
        titleLabel.snp.makeConstraints { (make) in
            make.leading.equalTo(44)
            make.trailing.equalTo(-44)
            make.centerY.equalTo(backButton)
        }
        
        marqueeView.snp.makeConstraints { (make) in
            make.top.equalTo(backButton.snp.bottom).offset(10)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(Device.size() > .screen4_7Inch ? 150 : 120)
        }
        
        NotificationCenter.default.rx.notification(UIApplication.didBecomeActiveNotification, object: nil)
            .subscribe(onNext: { [weak self] _ in
                guard let self = self else { return }
                switch self.viewState {
                case .initital: self.startEarthAnimation()
                case .loading: self.startSolarSystemAnimation()
                case .timeout: self.stopSolarSystemAnimation()
                default: break
                }
            })
            .disposed(by: disposeBag)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: true)
        self.navigationController?.interactivePopGestureRecognizer?.delegate = self as? UIGestureRecognizerDelegate
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        switch viewState {
        case .default:
            viewState = .initital
        case .loading, .list:
            startSolarSystemAnimation()
        default:
            break
        }
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    private func startEarthAnimation() {
        guard !starsView.isAnimationPlaying else {
            return
        }
        
        starsView.play()
        earthView.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
        earthView.startRotationAnimation()
        UIView.animate(withDuration: 1, delay: 0, usingSpringWithDamping: 0.3, initialSpringVelocity: 15, options: .curveEaseIn, animations: {
            self.earthView.alpha = 1
            self.earthView.transform = CGAffineTransform(scaleX: 1, y: 1)
        })
        
        discoverButton.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        UIView.animate(withDuration: 0.5, delay: 0.5, usingSpringWithDamping: 0.5, initialSpringVelocity: 15, options: .curveEaseInOut, animations: {
            self.discoverButton.transform = CGAffineTransform(scaleX: 1, y: 1)
            self.discoverButton.alpha = 1
            self.tryStealthButton.alpha = 1
        })
    }
    
    private func updateButtons() {
        discoverButton.isHidden = viewState != .initital
        if findFriendService.isAnonymous {
            tryStealthButton.isHidden = viewState != .initital
        } else {
            tryStealthButton.isHidden = true
        }
        loadingButton.isHidden = viewState != .loading
        retryButton.isHidden = viewState != .timeout
        marqueeView.isHidden = viewState == .list
        
        if viewState == .list {
            marqueeView.stop()
        }
    }
    
    private func startSolarSystemAnimation() {
        guard !solarView.isAnimationPlaying else {
            return
        }

        solarView.play()
        UIView.animate(withDuration: 1, animations: {
            self.earthView.alpha = 0
            self.starsView.alpha = 0
            self.solarView.alpha = 1
        }) { _ in
            self.starsView.stop()
            self.earthView.stopRotationAnimation()
        }
    }
    
    private func stopSolarSystemAnimation() {
        solarView.stop()
    }
    
    private func showResultList() {
        let vc = DiscoverListViewController(findFriendService: findFriendService)
        vc.dataSource = loadStrangers
        vc.view.translatesAutoresizingMaskIntoConstraints = false
        self.addChild(vc)
        self.view.addSubview(vc.view)
        vc.view.snp.makeConstraints({ (make) in
            make.top.equalTo(self.marqueeView)
            make.leading.trailing.bottom.equalToSuperview()
        })
        
        vc.view.alpha = 0
        vc.view.layoutIfNeeded()
        
        UIView.animate(withDuration: 0.8, animations: {
            vc.view.alpha = 1
        }) { _ in
            vc.didMove(toParent: self)
        }
    }
    
    private func hideResultList() {
        let vc = self.children.last
        vc?.view.removeFromSuperview()
        vc?.removeFromParent()
    }
    
    @objc
    private func goBack() {
        navigationController?.popViewController(animated: true)
    }

    @objc
    private func didClickTryStealth() {
        findFriendService.sendStop()
        findStrangers()
    }
    
    @objc
    private func didClickDiscover() {
        findFriendService.sendStart()
        findStrangers()
    }
    
    private func findStrangers() {
        viewState = .loading
        findFriendService.findStrangers()
            .subscribe(onNext: { [weak self] result in
                self?.loadStrangers = result ?? []
                self?.viewState = .list
                }, onError: { [weak self] _ in
                    if self?.viewState == .list {
                        ProgressHUD.showTextHUD(withText: NSLocalizedString("Please try again", comment: ""), in: self?.view)
                    } else {
                        self?.viewState = .timeout
                    }
            })
            .disposed(by: self.disposeBag)
    }
}

fileprivate extension UIView {
    
    func startRotationAnimation(duration: CFTimeInterval = 2.0) {
        let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotationAnimation.toValue = Double.pi * 2.0
        rotationAnimation.duration = duration
        rotationAnimation.isCumulative = true
        rotationAnimation.repeatCount = Float.infinity
        layer.add(rotationAnimation, forKey: "rotationAnimation")
    }
    
    func stopRotationAnimation() {
        layer.removeAllAnimations()
    }
}
