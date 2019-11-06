// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import UIKit

private struct Constants {
    static let SmallSize: CGFloat = 60.0
    static let BigSize: CGFloat = 80.0
    static let ImageSize: CGFloat = 30.0
}

enum ButtonSize {
    case small
    case big
}

enum CallButtonType {
    case decline
    case answerAudio
    case answerVideo
    case mute
    case speaker
    case video
}

class CallButton: UIButton {

    override var isSelected: Bool {
        didSet {
            if let selectedTintColor = selectedTintColor {
                tintColor = isSelected ? selectedTintColor : normalTintColor
            }
        }
    }

    override var isHighlighted: Bool {
        didSet {
            if isHighlighted {
                tintColor = normalTintColor
            }
            else {
                if let selectedTintColor = selectedTintColor {
                    tintColor = isSelected ? selectedTintColor : normalTintColor
                }
            }
        }
    }

    fileprivate let buttonSize: ButtonSize
    fileprivate let normalTintColor: UIColor
    fileprivate var selectedTintColor: UIColor?

    init(type: CallButtonType, buttonSize: ButtonSize) {
        self.buttonSize = buttonSize
        self.normalTintColor = UIColor.white

        super.init(frame: CGRect.zero)

        switch buttonSize {
            case .small:
                layer.cornerRadius = Constants.SmallSize / 2
            case .big:
                layer.cornerRadius = Constants.BigSize / 2
        }
        layer.masksToBounds = true

        let imageName: String
        var backgroundColor: UIColor? = nil
        var selectedBackgroundColor: UIColor? = nil

        switch type {
            case .decline:
                imageName = "end-call"
                backgroundColor = UIColor.tokNotice
            case .answerAudio:
                imageName = "start-call-30"
                backgroundColor = UIColor.tokOnline
            case .answerVideo:
                imageName = "video-call-30"
                backgroundColor = UIColor.tokOnline
            case .mute:
                imageName = "mute"
                selectedTintColor = UIColor.black
                selectedBackgroundColor = UIColor.white
                addBlurEffect()
            case .speaker:
                imageName = "speaker"
                selectedTintColor = UIColor.black
                selectedBackgroundColor = UIColor.white
                addBlurEffect()
            case .video:
                imageName = "video-call-30"
                selectedTintColor = UIColor.black
                selectedBackgroundColor = UIColor.white
                addBlurEffect()
        }

        tintColor = normalTintColor

        let image = UIImage.templateNamed(imageName)
        setImage(image, for: .normal)

        if let backgroundColor = backgroundColor {
            let backgroundImage = UIImage.imageWithColor(backgroundColor, size: CGSize(width: 1.0, height: 1.0))
            setBackgroundImage(backgroundImage, for: .normal)
        }
        if let selected = selectedBackgroundColor {
            let backgroundImage = UIImage.imageWithColor(selected, size: CGSize(width: 1.0, height: 1.0))
            setBackgroundImage(backgroundImage, for: .selected)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize : CGSize {
        switch buttonSize {
            case .small:
                return CGSize(width: Constants.SmallSize, height: Constants.SmallSize)
            case .big:
                return CGSize(width: Constants.BigSize, height: Constants.BigSize)
        }
    }
}

fileprivate extension UIButton {
    func addBlurEffect() {
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .light))
        blur.frame = CGRect(origin: .zero, size: intrinsicContentSize)
        blur.isUserInteractionEnabled = false
        insertSubview(blur, at: 0)
        if let imageView = self.imageView{
            bringSubviewToFront(imageView)
        }
    }
}
