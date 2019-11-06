// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import UIKit
import SnapKit

private struct Constants {
    
    static let AvatarSize = 100.0
    static let ButtonContainerBottomOffset = -20.0

    static let ButtonHorizontalOffset = 60.0
}

protocol CallIncomingControllerDelegate: class {
    func callIncomingControllerDecline(_ controller: CallIncomingController)
    func callIncomingControllerAnswerAudio(_ controller: CallIncomingController)
    func callIncomingControllerAnswerVideo(_ controller: CallIncomingController)
}

class CallIncomingController: CallBaseController {
    weak var delegate: CallIncomingControllerDelegate?

    fileprivate var buttonContainer: UIView!
    fileprivate var declineButton: CallButton!
    fileprivate var audioButton: CallButton!
    fileprivate var videoButton: CallButton!

    override func loadView() {
        super.loadView()

        createViews()
        installConstraints()

        infoLabel.text = NSLocalizedString("Incoming call", comment: "")
    }

    override func prepareForRemoval() {
        super.prepareForRemoval()

        declineButton.isEnabled = false
        audioButton.isEnabled = false
        videoButton.isEnabled = false
    }
}

// MARK: Actions
extension CallIncomingController {
    @objc func declineButtonPressed() {
        delegate?.callIncomingControllerDecline(self)
    }

    @objc func audioButtonPressed() {
        delegate?.callIncomingControllerAnswerAudio(self)
    }

    @objc func videoButtonPressed() {
        delegate?.callIncomingControllerAnswerVideo(self)
    }
}

private extension CallIncomingController {
    func createViews() {
        buttonContainer = UIView()
        buttonContainer.backgroundColor = .clear
        view.addSubview(buttonContainer)

        declineButton = CallButton(type: .decline, buttonSize: .small)
        declineButton.addTarget(self, action: #selector(CallIncomingController.declineButtonPressed), for: .touchUpInside)
        buttonContainer.addSubview(declineButton)

        audioButton = CallButton(type: .answerAudio, buttonSize: .small)
        audioButton.addTarget(self, action: #selector(CallIncomingController.audioButtonPressed), for: .touchUpInside)
        buttonContainer.addSubview(audioButton)

        videoButton = CallButton(type: .answerVideo, buttonSize: .small)
        videoButton.addTarget(self, action: #selector(CallIncomingController.videoButtonPressed), for: .touchUpInside)
        buttonContainer.addSubview(videoButton)
    }

    func installConstraints() {

        buttonContainer.snp.makeConstraints {
            $0.bottom.equalTo(view.safeArea.bottom).offset(Constants.ButtonContainerBottomOffset)
            $0.centerX.equalToSuperview()
        }

        declineButton.snp.makeConstraints {
            $0.centerY.equalTo(buttonContainer)
            $0.leading.equalTo(buttonContainer)
            $0.top.bottom.equalToSuperview()
        }

        videoButton.snp.makeConstraints {
            $0.width.equalTo(declineButton)
            $0.centerY.equalTo(buttonContainer)
            $0.leading.equalTo(declineButton.snp.trailing).offset(Constants.ButtonHorizontalOffset)
        }

        audioButton.snp.makeConstraints {
            $0.width.equalTo(declineButton)
            $0.centerY.equalTo(buttonContainer)
            $0.leading.equalTo(videoButton.snp.trailing).offset(Constants.ButtonHorizontalOffset)
            $0.trailing.equalTo(buttonContainer)
        }
    }
}
