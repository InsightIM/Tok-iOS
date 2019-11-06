// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation
import AVFoundation

enum Sound: String {
    case newMessage = "notification"
    case sent = "sent"
}

class AlertAudioPlayer {

    var playOnlyIfApplicationIsActive = true

    fileprivate var sounds: [Sound: SystemSoundID]!

    init() {
        sounds = [
            .newMessage: createSystemSoundForSound(.newMessage),
            .sent: createSystemSoundForSound(.sent),
        ]
    }

    deinit {
        for (_, systemSound) in sounds {
            AudioServicesDisposeSystemSoundID(systemSound)
        }
    }

    func playSound(_ sound: Sound) {
        if playOnlyIfApplicationIsActive && !UIApplication.isActive {
            return
        }

        guard let systemSound = sounds[sound] else {
            return
        }

        if sound == .sent {
            AudioServicesPlaySystemSound(systemSound) // play without vibration
        } else {
            AudioServicesPlayAlertSound(systemSound)
        }
    }
}

private extension AlertAudioPlayer {
    func createSystemSoundForSound(_ sound: Sound, exten: String = "caf") -> SystemSoundID {
        let url = Bundle.main.url(forResource: sound.rawValue, withExtension: exten)!

        var sound: SystemSoundID = 0
        AudioServicesCreateSystemSoundID(url as CFURL, &sound)
        return sound
    }
}

extension UIApplication {
    class var isActive: Bool {
        get {
            switch shared.applicationState {
            case .active:
                return true
            case .inactive:
                return false
            case .background:
                return false
            @unknown default:
                fatalError()
            }
        }
    }
}

class AudioPlayer {
    enum Sound: String {
        case Calltone = "isotoxin_Calltone"
        case Hangup = "isotoxin_Hangup"
        case Ringtone = "isotoxin_Ringtone"
        case RingtoneWhileCall = "isotoxin_RingtoneWhileCall"
    }
    
    var playOnlyIfApplicationIsActive = true
    
    fileprivate var players = [Sound: AVAudioPlayer]()
    
    func playSound(_ sound: Sound, loop: Bool) {
        if playOnlyIfApplicationIsActive && !UIApplication.isActive {
            return
        }
        
        guard let player = playerForSound(sound) else {
            return
        }
        
        player.numberOfLoops = loop ? -1 : 1
        player.currentTime = 0.0
        player.play()
    }
    
    func isPlayingSound(_ sound: Sound) -> Bool {
        guard let player = playerForSound(sound) else {
            return false
        }
        
        return player.isPlaying
    }
    
    func isPlaying() -> Bool {
        let pl = players.filter {
            $0.1.isPlaying
        }
        
        return !pl.isEmpty
    }
    
    func stopSound(_ sound: Sound) {
        guard let player = playerForSound(sound) else {
            return
        }
        player.stop()
    }
    
    func stopAll() {
        for (_, player) in players {
            player.stop()
        }
    }
}

private extension AudioPlayer {
    func playerForSound(_ sound: Sound) -> AVAudioPlayer? {
        if let player = players[sound] {
            return player
        }
        
        guard let path = Bundle.main.path(forResource: sound.rawValue, ofType: "aac") else {
            return nil
        }
        
        guard let player = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: path)) else {
            return nil
        }
        
        players[sound] = player
        return player
    }
}
