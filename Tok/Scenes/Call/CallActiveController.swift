// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import UIKit
import SnapKit

protocol CallActiveControllerDelegate: class {
    func callActiveController(_ controller: CallActiveController, mute: Bool)
    func callActiveController(_ controller: CallActiveController, speaker: Bool)
    func callActiveController(_ controller: CallActiveController, outgoingVideo: Bool)
    func callActiveControllerDecline(_ controller: CallActiveController)
    func callActiveControllerSwitchCamera(_ controller: CallActiveController)
}

private struct Constants {
    static let BigCenterContainerTopOffset = 50.0
    static let BigButtonOffset = 30.0

    static let SmallButtonOffset = 20.0
    static let SmallBottomOffset: CGFloat = -20.0

    static let VideoPreviewOffset = 20.0
    static let VideoPreviewSize = CGSize(width: 150.0, height: 110)
    static let SwitchCameraOffset = 5.0

    static let ControlsAnimationDuration = 0.3
}

class CallActiveController: CallBaseController {
    enum State {
        case none
        case reaching
        case active(duration: TimeInterval)
    }

    weak var delegate: CallActiveControllerDelegate?

    var state: State = .none {
        didSet {
            // load view
            _ = view

            switch state {
                case .none:
                    infoLabel.text = nil
                    durationLabel.text = nil
                case .reaching:
                    infoLabel.text = NSLocalizedString("Reaching...", comment: "")
                    durationLabel.text = nil

                    bigVideoButton?.isEnabled = false
                    smallVideoButton?.isEnabled = false
                case .active(let duration):
                    infoLabel.text = nil
                    durationLabel.text = String(timeInterval: duration)

                    bigVideoButton?.isEnabled = true
                    smallVideoButton?.isEnabled = true
            }
        }
    }

    var mute: Bool = false {
        didSet {
            bigMuteButton?.isSelected = mute
            smallMuteButton?.isSelected = mute
        }
    }

    var speaker: Bool = false {
        didSet {
            bigSpeakerButton?.isSelected = speaker
            smallSpeakerButton?.isSelected = speaker
        }
    }

    var outgoingVideo: Bool = false {
        didSet {
            bigVideoButton?.isSelected = outgoingVideo
            smallVideoButton?.isSelected = outgoingVideo
        }
    }

    var videoFeed: UIView? {
        didSet {
            if oldValue === videoFeed {
                return
            }

            if let old = oldValue {
                old.removeFromSuperview()
            }

            if let feed = videoFeed {
                view.insertSubview(feed, belowSubview: videoPreviewView)

                feed.bounds.size = view.bounds.size

                feed.snp.makeConstraints {
                    $0.edges.equalTo(view)
                }

                updateViewsWithTraitCollection(self.traitCollection)
            }
        }
    }

    var videoPreviewLayer: CALayer? {
        didSet {
            if oldValue === videoPreviewLayer {
                return
            }

            if let old = oldValue {
                old.removeFromSuperlayer()
                videoPreviewView.isHidden = true
            }

            if let layer = videoPreviewLayer {
                videoPreviewView.layer.addSublayer(layer)
                videoPreviewView.bringSubviewToFront(switchCameraButton)
                videoPreviewView.isHidden = false
                view.layoutIfNeeded()
            }

            updateViewsWithTraitCollection(self.traitCollection)
        }
    }

    fileprivate var showControls = true {
        didSet {
            let offset = showControls ? Constants.SmallBottomOffset : smallContainerView.frame.size.height + Constants.SmallBottomOffset
            smallContainerViewBottomConstraint.update(offset: offset)

            toggleTopContainer(hidden: !showControls)

            UIView.animate(withDuration: Constants.ControlsAnimationDuration, animations: {
                self.view.layoutIfNeeded()
                self.smallContainerView.alpha = self.showControls ? 1 : 0
            }) 
        }
    }

    fileprivate var videoPreviewView: UIView!
    fileprivate var switchCameraButton: UIButton!

    fileprivate var bigContainerView: UIView!
    fileprivate var bigCenterContainer: UIView!
    fileprivate var bigMuteButton: CallButton?
    fileprivate var bigSpeakerButton: CallButton?
    fileprivate var bigVideoButton: CallButton?
    fileprivate var bigDeclineButton: CallButton?

    fileprivate var smallContainerViewBottomConstraint: Constraint!

    fileprivate var smallContainerView: UIView!
    fileprivate var smallMuteButton: CallButton?
    fileprivate var smallSpeakerButton: CallButton?
    fileprivate var smallVideoButton: CallButton?
    fileprivate var smallDeclineButton: CallButton?

    lazy var durationLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.white
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 18.0, weight: .light)
        return label
    }()
    
    override func loadView() {
        super.loadView()

        createGestureRecognizers()
        createVideoPreviewView()
        createBigViews()
        createSmallViews()
        installConstraints()

        view.bringSubviewToFront(topContainer)

        setButtonsInitValues()

        updateViewsWithTraitCollection(self.traitCollection)
    }

    override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        updateViewsWithTraitCollection(newCollection)
        showControls = true
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if let layer = videoPreviewLayer {
            layer.frame.size = videoPreviewView.frame.size
        }
    }

    override func prepareForRemoval() {
        super.prepareForRemoval()

        bigMuteButton?.isEnabled = false
        bigSpeakerButton?.isEnabled = false
        bigVideoButton?.isEnabled = false
        bigDeclineButton?.isEnabled = false

        smallMuteButton?.isEnabled = false
        smallSpeakerButton?.isEnabled = false
        smallVideoButton?.isEnabled = false
        smallDeclineButton?.isEnabled = false
    }
}

// MARK: Actions
extension CallActiveController {
    @objc func tapOnView() {
        guard !smallContainerView.isHidden else {
            return
        }

        showControls = !showControls
    }

    @objc func muteButtonPressed(_ button: CallButton) {
        mute = !button.isSelected
        delegate?.callActiveController(self, mute: mute)
    }

    @objc func speakerButtonPressed(_ button: CallButton) {
        speaker = !button.isSelected
        delegate?.callActiveController(self, speaker: speaker)
    }

    @objc func videoButtonPressed(_ button: CallButton) {
        outgoingVideo = !button.isSelected
        delegate?.callActiveController(self, outgoingVideo: outgoingVideo)
    }

    @objc func declineButtonPressed() {
        delegate?.callActiveControllerDecline(self)
    }

    @objc func switchCameraButtonPressed() {
        delegate?.callActiveControllerSwitchCamera(self)
    }
}

private extension CallActiveController {
    func createGestureRecognizers() {
        let tapGR = UITapGestureRecognizer(target: self, action: #selector(CallActiveController.tapOnView))
        view.addGestureRecognizer(tapGR)
    }

    func createVideoPreviewView() {
        videoPreviewView = UIView()
        videoPreviewView.backgroundColor = UIColor.black
        view.addSubview(videoPreviewView)

        videoPreviewView.isHidden = !outgoingVideo

        let image = UIImage.templateNamed("switch-camera")

        switchCameraButton = UIButton()
        switchCameraButton.tintColor = UIColor.white
        switchCameraButton.setImage(image, for: .normal)
        switchCameraButton.addTarget(self, action: #selector(CallActiveController.switchCameraButtonPressed), for: .touchUpInside)
        videoPreviewView.addSubview(switchCameraButton)
    }

    func createBigViews() {
        bigContainerView = UIView()
        bigContainerView.backgroundColor = .clear
        view.addSubview(bigContainerView)

        bigCenterContainer = UIView()
        bigCenterContainer.backgroundColor = .clear
        bigContainerView.addSubview(bigCenterContainer)

        bigMuteButton = addButtonWithType(.mute, buttonSize: .big, action: #selector(CallActiveController.muteButtonPressed(_:)), container: bigCenterContainer)
        bigSpeakerButton = addButtonWithType(.speaker, buttonSize: .big, action: #selector(CallActiveController.speakerButtonPressed(_:)), container: bigCenterContainer)
        bigVideoButton = addButtonWithType(.video, buttonSize: .big, action: #selector(CallActiveController.videoButtonPressed(_:)), container: bigCenterContainer)
        bigDeclineButton = addButtonWithType(.decline, buttonSize: .big, action: #selector(CallActiveController.declineButtonPressed), container: bigContainerView)
    }

    func createSmallViews() {
        smallContainerView = UIView()
        smallContainerView.backgroundColor = .clear
        view.addSubview(smallContainerView)

        smallMuteButton = addButtonWithType(.mute, buttonSize: .small, action: #selector(CallActiveController.muteButtonPressed(_:)), container: smallContainerView)
        smallSpeakerButton = addButtonWithType(.speaker, buttonSize: .small, action: #selector(CallActiveController.speakerButtonPressed(_:)), container: smallContainerView)
        smallVideoButton = addButtonWithType(.video, buttonSize: .small, action: #selector(CallActiveController.videoButtonPressed(_:)), container: smallContainerView)
        smallDeclineButton = addButtonWithType(.decline, buttonSize: .small, action: #selector(CallActiveController.declineButtonPressed), container: smallContainerView)
        
        smallContainerView.addSubview(durationLabel)
        durationLabel.snp.makeConstraints { (make) in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(smallContainerView.snp.top).offset(-10)
        }
    }

    func addButtonWithType(_ type: CallButtonType, buttonSize: ButtonSize, action: Selector, container: UIView) -> CallButton {
        let button = CallButton(type: type, buttonSize: buttonSize)
        button.addTarget(self, action: action, for: .touchUpInside)
        container.addSubview(button)

        return button
    }

    func installConstraints() {
        videoPreviewView.snp.makeConstraints {
            $0.trailing.equalTo(-Constants.VideoPreviewOffset)
            $0.top.equalTo(view.safeArea.top).offset(Constants.VideoPreviewOffset)
            $0.width.equalTo(Constants.VideoPreviewSize.width)
            $0.height.equalTo(Constants.VideoPreviewSize.height)
        }

        switchCameraButton.snp.makeConstraints {
            $0.top.equalTo(videoPreviewView).offset(Constants.SwitchCameraOffset)
            $0.trailing.equalTo(videoPreviewView).offset(-Constants.SwitchCameraOffset)
        }

        bigContainerView.snp.makeConstraints {
            $0.top.equalTo(topContainer.snp.bottom)
            $0.leading.trailing.equalTo(view)
            $0.bottom.equalTo(view.safeArea.bottom)
        }

        bigCenterContainer.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
        }
        
        bigVideoButton!.snp.makeConstraints {
            $0.top.bottom.equalToSuperview()
            $0.centerX.equalToSuperview()
        }
        
        bigSpeakerButton!.snp.makeConstraints {
            $0.centerY.equalTo(bigVideoButton!)
            $0.trailing.equalTo(bigVideoButton!.snp.leading).offset(-20)
        }

        bigMuteButton!.snp.makeConstraints {
            $0.centerY.equalTo(bigVideoButton!)
            $0.leading.equalTo(bigVideoButton!.snp.trailing).offset(20)
        }

        bigDeclineButton!.snp.makeConstraints {
            $0.centerX.equalTo(bigContainerView)
            $0.top.equalTo(bigCenterContainer.snp.bottom).offset(Constants.BigButtonOffset)
            $0.bottom.equalTo(bigContainerView).offset(-Constants.BigButtonOffset)
        }

        smallContainerView.snp.makeConstraints {
            smallContainerViewBottomConstraint = $0.bottom.equalTo(view.safeArea.bottom).offset(Constants.SmallBottomOffset).constraint
            $0.centerX.equalTo(view)
        }

        smallMuteButton!.snp.makeConstraints {
            $0.top.bottom.equalTo(smallContainerView)
            $0.leading.equalTo(smallContainerView)
        }

        smallSpeakerButton!.snp.makeConstraints {
            $0.top.bottom.equalTo(smallContainerView)
            $0.leading.equalTo(smallMuteButton!.snp.trailing).offset(Constants.SmallButtonOffset)
        }

        smallVideoButton!.snp.makeConstraints {
            $0.top.bottom.equalTo(smallContainerView)
            $0.leading.equalTo(smallSpeakerButton!.snp.trailing).offset(Constants.SmallButtonOffset)
        }

        smallDeclineButton!.snp.makeConstraints {
            $0.top.bottom.equalTo(smallContainerView)
            $0.leading.equalTo(smallVideoButton!.snp.trailing).offset(Constants.SmallButtonOffset)
            $0.trailing.equalTo(smallContainerView)
        }
    }

    func setButtonsInitValues() {
        bigMuteButton?.isSelected = mute
        smallMuteButton?.isSelected = mute

        bigSpeakerButton?.isSelected = speaker
        smallSpeakerButton?.isSelected = speaker

        bigVideoButton?.isSelected = outgoingVideo
        smallVideoButton?.isSelected = outgoingVideo
    }

    func updateViewsWithTraitCollection(_ traitCollection: UITraitCollection) {
        if videoFeed != nil || videoPreviewLayer != nil {
            bigContainerView.isHidden = true
            smallContainerView.isHidden = false
            topContainer.isHidden = true
            return
        }

        switch traitCollection.verticalSizeClass {
            case .regular:
                bigContainerView.isHidden = false
                smallContainerView.isHidden = true
                topContainer.isHidden = false
            case .unspecified:
                fallthrough
            case .compact:
                bigContainerView.isHidden = true
                smallContainerView.isHidden = false
                topContainer.isHidden = true
        }
    }
}
