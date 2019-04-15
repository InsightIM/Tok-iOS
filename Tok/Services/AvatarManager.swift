// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation

class AvatarManager {
    fileprivate let cache: NSCache<NSString, UIImage>
    
    static let shared = AvatarManager()
    
    init() {
        self.cache = NSCache()
    }

    /**
        Returns round avatar created from string with a given diameter. Searches for an avatar in cache first,
        if not found creates it.

        - Parameters:
          - string: String to create avatar from. In case of empty string avatar will be set to "?".
          - diameter: Diameter of circle with avatar.

        - Returns: Avatar from given string with given size.
     */
    func avatarFromString(_ string: String, diameter: CGFloat) -> UIImage {
        var string = string

        if string.isEmpty {
            string = "?"
        }

        let key = keyFromString(string, diameter: diameter) as NSString

        if let avatar = cache.object(forKey: key) {
            return avatar
        }

        let avatar = createAvatarFromString(string, diameter: diameter)
        cache.setObject(avatar, forKey: key)

        return avatar
    }
    
    func groupAvatar(for chat: OCTChat) -> UIImage? {
        guard chat.isGroup, let key = chat.uniqueIdentifier as NSString? else {
            return nil
        }
        
        if let cacheImage = cache.object(forKey: key) {
            return cacheImage
        }
        
        let peers = UserService.shared.toxMananger!.objects.peers(predicate: NSPredicate(format: "groupNumber == %d AND avatarData != null", chat.groupNumber))
        let defaultAvatar = UIImage(named: "GroupAvatar")!
        guard peers.count > 0 else {
            cache.setObject(defaultAvatar, forKey: key)
            return defaultAvatar
        }
        
        let list: [OCTPeer] = peers.toList()
        let image = UIImage.groupIcon(with: list.map { $0.avatarData }.compactMap { $0 }) ?? defaultAvatar
        cache.setObject(image, forKey: key)
        return image
    }
}

private extension AvatarManager {
    func keyFromString(_ string: String, diameter: CGFloat) -> String {
        return "\(string)-\(diameter)"
    }

    func createAvatarFromString(_ string: String, diameter: CGFloat) -> UIImage {
        let avatarString = avatarStringFromString(string)

        let label = UILabel()
        label.layer.borderWidth = 1.0
        label.layer.masksToBounds = true
        label.textAlignment = .center
        label.text = avatarString

        label.backgroundColor = UIColor.tokBackgroundColor
        label.layer.borderColor = UIColor.tokBlue.cgColor
        label.textColor = UIColor.tokBlue

        var size: CGSize
        var fontSize = diameter

        repeat {
            fontSize -= 1

            let font = UIFont.systemFont(ofSize: fontSize, weight: .light)
            size = avatarString.stringSizeWithFont(font)
        }
        while (max(size.width, size.height) > diameter)

        let frame = CGRect(x: 0, y: 0, width: diameter, height: diameter)

        label.font = UIFont.systemFont(ofSize: fontSize * 0.6, weight: .light)
        label.layer.cornerRadius = AvatarConstants.CornerRadius
        label.frame = frame

        return imageWithLabel(label)
    }

    func avatarStringFromString(_ string: String) -> String {
        guard !string.isEmpty else {
            return ""
        }

        // Avatar can have alphanumeric symbols and ? sign.
        let badSymbols = (CharacterSet.alphanumerics.inverted as NSCharacterSet).mutableCopy() as! NSMutableCharacterSet
        badSymbols.removeCharacters(in: "?")

        let words = string.components(separatedBy: CharacterSet.whitespaces).map {
            $0.components(separatedBy: badSymbols as CharacterSet).joined(separator: "")
        }.filter {
            !$0.isEmpty
        }

        var result = words.map {
            $0.isEmpty ? "" : $0[$0.startIndex ..< $0.index($0.startIndex, offsetBy: 1)]
        }.joined(separator: "")

        let numberOfLetters = min(2, result.count)

        result = result.uppercased()
        return String(result[result.startIndex ..< result.index(result.startIndex, offsetBy: numberOfLetters)])
    }

    func imageWithLabel(_ label: UILabel) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(label.bounds.size, false, 0.0)
        label.layer.render(in: UIGraphicsGetCurrentContext()!)

        let image = UIGraphicsGetImageFromCurrentImageContext()

        UIGraphicsEndImageContext()

        return image!
    }
}

extension AvatarManager {
    
    func image(with friend: OCTFriend) -> UIImage? {
        return image(with: friend.avatarData, identityNumber: Int(friend.friendNumber), name: friend.nickname)
    }
    
    func image(with peer: OCTPeer) -> UIImage? {
        let identityNumber: Int = Int(arc4random() % 8 + 1)
        return image(with: peer.avatarData, identityNumber:identityNumber, name: peer.nickname)
    }
    
    func image(with data: Data?, identityNumber: Int, name: String?) -> UIImage? {
        if let data = data {
            return UIImage(data: data)
        } else {
            return UIImage(named: "color\(identityNumber % 8 + 1)")
        }
    }
}
