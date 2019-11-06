// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation

struct AvatarConstants {
    static let CornerRadius: CGFloat = 4.0
}

class AvatarManager {
    fileprivate let cache: NSCache<NSString, UIImage>
    
    static let shared = AvatarManager()
    
    init() {
        self.cache = NSCache()
    }
    
    private static func makeImage(name: String?, publicKey: String) -> UIImage? {
        let letters = name ?? publicKey
        if let firstLetter = letters.first {
            let colorIndex = firstLetter.asciiValue % 8 + 1
            let image = UIImage(named: "color\(colorIndex)")!
            let text = String([firstLetter]).uppercased()
            let textSize = CGSize(width: image.size.width * 0.8,
                                  height: image.size.height * 0.8)
            let avatar = image.drawText(text: text,
                                        offset: .zero,
                                        fontSize: fontSize(forText: text, size: textSize))
            return avatar
        }
        return nil
    }
    
    private static func fontSize(forText text: String, size greatestSize: CGSize) -> CGFloat {
        let maxFontSize = 30
        let minFontSize = 12
        let nsText = text as NSString
        for i in minFontSize...maxFontSize {
            let attributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: CGFloat(i))]
            let size = nsText.boundingRect(with: UIView.layoutFittingCompressedSize, options: .usesLineFragmentOrigin, attributes: attributes, context: nil)
            if size.width > greatestSize.width || size.height > greatestSize.height {
                return CGFloat(i - 1)
            }
        }
        return CGFloat(maxFontSize)
    }
    
    private static func puzzleImages(rectangleRect: CGRect, squareRect: CGRect, images: [UIImage]) -> UIImage {
        let rect = CGRect(x: 0, y: 0, width: 512, height: 512)
        let separatorLineWidth: CGFloat = 4 * UIScreen.main.scale
        
        guard !images.isEmpty else {
            return defaultAvatar()
        }
        let images = images.map { (image) -> UIImage in
            if abs(image.size.width - image.size.height) > 1 {
                if image.size.width > image.size.height {
                    let rect = CGRect(x: (image.size.width - image.size.height) / 2 ,
                                      y: 0,
                                      width: image.size.height,
                                      height: image.size.height)
                    return self.image(withImage: image, rect: rect)
                } else {
                    let rect = CGRect(x: 0,
                                      y: (image.size.height - image.size.width) / 2,
                                      width: image.size.width,
                                      height: image.size.width)
                    return self.image(withImage: image, rect: rect)
                }
            } else {
                return image
            }
        }
        UIGraphicsBeginImageContext(rect.size)
        UIBezierPath(roundedRect: rect, cornerRadius: rect.width / 2).addClip()
        if images.count == 1 {
            images[0].draw(in: rect)
        } else if images.count == 2 {
            let croppedImages = [self.image(withImage: images[0], relativeRect: rectangleRect),
                                 self.image(withImage: images[1], relativeRect: rectangleRect)]
            croppedImages[0].draw(in: CGRect(x: 0, y: 0, width: rect.width / 2, height: rect.height))
            croppedImages[1].draw(in: CGRect(x: rect.width / 2, y: 0, width: rect.width / 2, height: rect.height))
            let colors = [UIColor.white.withAlphaComponent(0).cgColor, UIColor.white.withAlphaComponent(0.9).cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            let locations: [CGFloat] = [0, 0.5, 1]
            if let ctx = UIGraphicsGetCurrentContext(), let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations) {
                let separatorLineRect = CGRect(x: (rect.width - separatorLineWidth) / 2, y: 0, width: separatorLineWidth, height: rect.height)
                let path = UIBezierPath(rect: separatorLineRect)
                path.addClip()
                let start = CGPoint(x: separatorLineRect.midX, y: separatorLineRect.minY)
                let end = CGPoint(x: separatorLineRect.midX, y: separatorLineRect.maxY)
                ctx.drawLinearGradient(gradient, start: start, end: end, options: [])
            }
        } else if images.count == 3 {
            let croppedImages = [self.image(withImage: images[0], relativeRect: rectangleRect),
                                 self.image(withImage: images[1], relativeRect: squareRect),
                                 self.image(withImage: images[2], relativeRect: squareRect)]
            croppedImages[0].draw(in: CGRect(x: 0, y: 0, width: rect.width / 2, height: rect.height))
            croppedImages[1].draw(in: CGRect(x: rect.width / 2, y: 0, width: rect.width / 2, height: rect.height / 2))
            croppedImages[2].draw(in: CGRect(x: rect.width / 2, y: rect.height / 2, width: rect.width / 2, height: rect.height / 2))
            let verticalColors = [UIColor.white.withAlphaComponent(0).cgColor, UIColor.white.withAlphaComponent(0.9).cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            let verticalLocations: [CGFloat] = [0, 0.5, 1]
            let horizontalColors = [UIColor.white.withAlphaComponent(0.9).cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            let horizontalLocations: [CGFloat] = [0, 1]
            let colorsSpace = CGColorSpaceCreateDeviceRGB()
            if let ctx = UIGraphicsGetCurrentContext(), let verticalGradient = CGGradient(colorsSpace: colorsSpace, colors: verticalColors, locations: verticalLocations), let horizontalGradient = CGGradient(colorsSpace: colorsSpace, colors: horizontalColors, locations: horizontalLocations) {
                ctx.saveGState()
                let verticalLineRect = CGRect(x: (rect.width - separatorLineWidth) / 2, y: 0, width: separatorLineWidth, height: rect.height)
                let verticalLinePath = UIBezierPath(rect: verticalLineRect)
                verticalLinePath.addClip()
                let verticalStart = CGPoint(x: verticalLineRect.midX, y: verticalLineRect.minY)
                let verticalEnd = CGPoint(x: verticalLineRect.midX, y: verticalLineRect.maxY)
                ctx.drawLinearGradient(verticalGradient, start: verticalStart, end: verticalEnd, options: [])
                ctx.restoreGState()
                
                let horizontalLineRect = CGRect(x: rect.width / 2, y: (rect.height - separatorLineWidth) / 2, width: rect.width / 2, height: separatorLineWidth)
                let horizontalLinePath = UIBezierPath(rect: horizontalLineRect)
                horizontalLinePath.addClip()
                let horizontalStart = CGPoint(x: horizontalLineRect.minX, y: horizontalLineRect.midY)
                let horizontalEnd = CGPoint(x: horizontalLineRect.maxX, y: horizontalLineRect.midY)
                ctx.drawLinearGradient(horizontalGradient, start: horizontalStart, end: horizontalEnd, options: [])
            }
        } else if images.count >= 4 {
            let croppedImages = [self.image(withImage: images[0], relativeRect: squareRect),
                                 self.image(withImage: images[1], relativeRect: squareRect),
                                 self.image(withImage: images[2], relativeRect: squareRect),
                                 self.image(withImage: images[3], relativeRect: squareRect)]
            croppedImages[0].draw(in: CGRect(x: 0, y: 0, width: rect.width / 2, height: rect.height / 2))
            croppedImages[1].draw(in: CGRect(x: rect.width / 2, y: 0, width: rect.width / 2, height: rect.height / 2))
            croppedImages[2].draw(in: CGRect(x: 0, y: rect.height / 2, width: rect.width / 2, height: rect.height / 2))
            croppedImages[3].draw(in: CGRect(x: rect.width / 2, y: rect.height / 2, width: rect.width / 2, height: rect.height / 2))
            let colors = [UIColor.white.withAlphaComponent(0).cgColor, UIColor.white.withAlphaComponent(0.9).cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            let locations: [CGFloat] = [0, 0.5, 1]
            if let ctx = UIGraphicsGetCurrentContext(), let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations) {
                ctx.saveGState()
                let verticalLineRect = CGRect(x: (rect.width - separatorLineWidth) / 2, y: 0, width: separatorLineWidth, height: rect.height)
                let verticalLinePath = UIBezierPath(rect: verticalLineRect)
                verticalLinePath.addClip()
                let verticalStart = CGPoint(x: verticalLineRect.midX, y: verticalLineRect.minY)
                let verticalEnd = CGPoint(x: verticalLineRect.midX, y: verticalLineRect.maxY)
                ctx.drawLinearGradient(gradient, start: verticalStart, end: verticalEnd, options: [])
                ctx.restoreGState()
                
                let horizontalLineRect = CGRect(x: 0, y: (rect.height - separatorLineWidth) / 2, width: rect.width, height: separatorLineWidth)
                let horizontalLinePath = UIBezierPath(rect: horizontalLineRect)
                horizontalLinePath.addClip()
                let horizontalStart = CGPoint(x: horizontalLineRect.minX, y: horizontalLineRect.midY)
                let horizontalEnd = CGPoint(x: horizontalLineRect.maxX, y: horizontalLineRect.midY)
                ctx.drawLinearGradient(gradient, start: horizontalStart, end: horizontalEnd, options: [])
            }
        }
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image ?? defaultAvatar()
    }
    
    private static func defaultAvatar() -> UIImage {
        return UIImage(named: "GroupAvatar")!
    }
    
    private static func image(withImage source: UIImage, relativeRect rect: CGRect) -> UIImage {
        let absoluteRect = CGRect(x: rect.origin.x * source.size.width,
                                  y: rect.origin.y * source.size.height,
                                  width: rect.width * source.size.width,
                                  height: rect.height * source.size.height)
        return image(withImage: source, rect: absoluteRect)
    }
    
    private static func image(withImage source: UIImage, rect: CGRect) -> UIImage {
        guard let cgImage = source.cgImage else {
            return source
        }
        let croppingRect = CGRect(x: rect.origin.x * source.scale,
                                  y: rect.origin.y * source.scale,
                                  width: rect.width * source.scale,
                                  height: rect.height * source.scale)
        if let cropped = cgImage.cropping(to: croppingRect) {
            return UIImage(cgImage: cropped, scale: source.scale, orientation: source.imageOrientation)
        } else {
            return source
        }
    }
    
    private static func offset(forIndex index: Int, of count: Int) -> CGPoint {
        let offset: CGFloat = (1 - sqrt(2) / 2) / 4
        switch count {
        case 0, 1:
            return .zero
        case 2:
            switch index {
            case 0:
                return CGPoint(x: offset / 2, y: 0)
            default:
                return CGPoint(x: -offset / 2, y: 0)
            }
        case 3:
            switch index {
            case 0:
                return CGPoint(x: offset / 2, y: 0)
            case 1:
                return CGPoint(x: -offset, y: offset)
            default:
                return CGPoint(x: -offset, y: -offset)
            }
        default:
            switch index {
            case 0:
                return CGPoint(x: offset, y: offset)
            case 1:
                return CGPoint(x: -offset, y: offset)
            case 2:
                return CGPoint(x: offset, y: -offset)
            default:
                return CGPoint(x: -offset, y: -offset)
            }
        }
    }
}

extension AvatarManager {
    func userAvatar(messageService: MessageService) -> UIImage {
        return image(bySenderId: "", messageService: messageService)
    }
    
    func image(bySenderId publicKey: String, messageService: MessageService) -> UIImage {
        if let avatar = cache.object(forKey: publicKey as NSString) {
            return avatar
        }
        
        let budildDefaultAvatar = { (name: String) -> UIImage in
            return AvatarManager.makeImage(name: name, publicKey: "?")!
        }
        
        let cacheAvatar: (UIImage, String) -> UIImage = { image, key in
            AvatarManager.shared.cache.setObject(image, forKey: key as NSString)
            return image
        }
        
        let database = messageService.database
        let isMe = publicKey.isEmpty || publicKey == messageService.tokManager.tox.publicKey
        if isMe { // Self
            let key = messageService.tokManager.tox.publicKey!
            let avatar = {
                budildDefaultAvatar(messageService.tokManager.tox.userName() ?? "?")
            }
            if let data = database.settingsStorage()?.userAvatarData {
                let image = UIImage(data: data) ?? avatar()
                return cacheAvatar(image, key)
            }
            return avatar()
        }
        
        return avatar(publicKey: publicKey, database: database) ?? budildDefaultAvatar("?")
    }
    
    func clearGroupImageCache(with chat: OCTChat) {
        guard chat.isGroup, let key = chat.uniqueIdentifier as NSString? else {
            return
        }
        cache.removeObject(forKey: key)
    }
}

private extension Character {
    var asciiValue: Int {
        get {
            let s = String(self).unicodeScalars
            return Int(s[s.startIndex].value)
        }
    }
}

// NEW

extension AvatarManager {
    func chatAvatar(chatId: String, database: Database) -> UIImage? {
        guard let chat = database.findChat(byId: chatId) else {
            return nil
        }
        if chat.isGroup {
            return groupAvatar(for: chat.groupNumber, database: database)
        }
        if let friend = chat.friends?.firstObject() as? OCTFriend {
            return friendAvatar(publicKey: friend.publicKey, database: database)
        }
        return nil
    }
    
    private func avatar(publicKey: String, database: Database) -> UIImage? {
        if let image = cache.object(forKey: publicKey as NSString) {
            return image
        }
        if let _ = database.findFriend(withPublicKey: publicKey), let image = friendAvatar(publicKey: publicKey, database: database) {
            return image
        }
        return peerAvatar(publicKey: publicKey, database: database)
    }
    
    func friendAvatar(publicKey: String, database: Database) -> UIImage? {
        if let image = cache.object(forKey: publicKey as NSString) {
            return image
        }
        let friend = database.findFriend(withPublicKey: publicKey)
        if let data = friend?.avatarData, let avatar = UIImage(data: data) {
            cache.setObject(avatar, forKey: publicKey as NSString)
            return avatar
        }
        if let avatar = AvatarManager.makeImage(name: friend?.nickname, publicKey: publicKey) {
            return avatar
        }
        return nil
    }
    
    func peerAvatar(publicKey: String, database: Database) -> UIImage? {
        if let image = cache.object(forKey: publicKey as NSString) {
            return image
        }
        let peer = database.findPeer(withPublicKey: publicKey)
        if let avatar = AvatarManager.makeImage(name: peer?.nickname, publicKey: publicKey) {
            cache.setObject(avatar, forKey: publicKey as NSString)
            return avatar
        }
        return nil
    }
    
    func groupAvatar(for groupNumber: Int, forceUpdate: Bool = false, database: Database) -> UIImage? {
        let key = "GroupChat_\(groupNumber)" as NSString
        if forceUpdate == false, let cacheImage = cache.object(forKey: key) {
            return cacheImage
        }
        
        let peers = database.peers(groupNumber: UInt64(groupNumber))
        let defaultAvatar = UIImage(named: "GroupAvatar")!
        guard peers.count > 0 else {
            return defaultAvatar
        }
        
        let images = (0..<min(peers.count, 9)).compactMap { i -> UIImage? in
            let peer = peers[i] as OCTPeer
            guard let pk = peer.publicKey else {
                return nil
            }
            return avatar(publicKey: pk, database: database)
        }
        
        if images.count > 1, let image = UIImage.makeGroupIcon(images) {
            cache.setObject(image, forKey: key)
            return image
        }
        return defaultAvatar
    }
}
