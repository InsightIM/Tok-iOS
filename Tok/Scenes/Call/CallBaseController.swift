// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import UIKit
import SnapKit

private struct Constants {
    static let TopContainerOffset: CGFloat = 50.0
    static let AvatarSize = 100.0
    static let CallerLabelTopOffset = 15.0
    static let InfoLabelTopOffset = 5.0
    static let LabelHorizontalOffset = 20.0
}

class CallBaseController: UIViewController {
    let call: OCTCall
    let callerName: String

    var topContainer: UIView!
    var callerLabel: UILabel!
    var infoLabel: UILabel!
    
    var effectView: UIView!

    fileprivate lazy var backgroundView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        
        let backView = UIView()
        backView.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.3)
        imageView.addSubview(backView)
        backView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        return imageView
    }()
    
    fileprivate lazy var avatarView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.layer.cornerRadius = 5
        imageView.layer.masksToBounds = true
        return imageView
    }()
    
    init(call: OCTCall) {
        self.call = call
        let friend = call.chat.friends?.firstObject() as? OCTFriend
        self.callerName = friend?.nickname ?? ""

        super.init(nibName: nil, bundle: nil)
        
        backgroundView.image = friend?.avatar
        avatarView.image = friend?.avatar
    }

    required convenience init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        loadViewWithBackgroundColor(.tokBlack)

        addBlurredBackground()
        createTopViews()
        installConstraints()
    }

    /**
        Prepare for removal by disabling all active views.
     */
    func prepareForRemoval() {
        infoLabel.text = NSLocalizedString("Call ended", comment: "")
    }

    func toggleTopContainer(hidden: Bool) {
        let offset = hidden ? (-Constants.TopContainerOffset-topContainer.height) : Constants.TopContainerOffset
        topContainer.snp.updateConstraints {
            $0.top.equalTo(view.safeArea.top).offset(offset)
        }
    }
}

private extension CallBaseController {
    func addBlurredBackground() {
        let blurEffect = UIBlurEffect(style: .dark)
        let effectView = UIVisualEffectView(effect: blurEffect)
        effectView.frame = view.bounds

        view.insertSubview(effectView, at: 0)
        effectView.snp.makeConstraints {
            $0.edges.equalTo(view)
        }
        
        view.insertSubview(backgroundView, belowSubview: effectView)
        backgroundView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        self.effectView = effectView
    }

    func createTopViews() {
        topContainer = UIView()
        view.addSubview(topContainer)
        
        topContainer.addSubview(avatarView)
        
        callerLabel = UILabel()
        callerLabel.text = callerName
        callerLabel.textColor = UIColor.white
        callerLabel.textAlignment = .center
        callerLabel.font = UIFont.systemFont(ofSize: 28.0)
        topContainer.addSubview(callerLabel)

        infoLabel = UILabel()
        infoLabel.textColor = UIColor.white
        infoLabel.textAlignment = .center
        infoLabel.font = UIFont.systemFont(ofSize: 18.0, weight: .light)
        topContainer.addSubview(infoLabel)
    }

    func installConstraints() {
        topContainer.snp.makeConstraints {
            $0.top.equalTo(view.safeArea.top).offset(Constants.TopContainerOffset)
            $0.leading.trailing.equalToSuperview()
        }
        
        avatarView.snp.makeConstraints { (make) in
            make.size.equalTo(Constants.AvatarSize)
            make.centerX.equalToSuperview()
            make.top.equalToSuperview()
        }

        callerLabel.snp.makeConstraints {
            $0.top.equalTo(avatarView.snp.bottom).offset(Constants.CallerLabelTopOffset)
            $0.leading.equalTo(topContainer).offset(Constants.LabelHorizontalOffset)
            $0.trailing.equalTo(topContainer).offset(-Constants.LabelHorizontalOffset)
        }

        infoLabel.snp.makeConstraints {
            $0.top.equalTo(callerLabel.snp.bottom).offset(Constants.InfoLabelTopOffset)
            $0.leading.equalTo(topContainer).offset(Constants.LabelHorizontalOffset)
            $0.trailing.equalTo(topContainer).offset(-Constants.LabelHorizontalOffset)
            $0.bottom.equalToSuperview()
        }
    }
}

extension UIViewController {
    func loadViewWithBackgroundColor(_ backgroundColor: UIColor) {
        let frame = CGRect(origin: CGPoint.zero, size: UIScreen.main.bounds.size)
        
        view = UIView(frame: frame)
        view.backgroundColor = backgroundColor
    }
}
