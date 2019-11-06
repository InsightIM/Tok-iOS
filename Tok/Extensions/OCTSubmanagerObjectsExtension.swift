// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation

//extension OCTSubmanagerObjects {
//    /// Without Bots And Unappcept friend
//    func normalFriends() -> Results<OCTFriend> {
//        let withoutBotsPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
//            NSPredicate(format: "publicKey != %@", BotService.shared.groupBot.publicKey),
//            NSPredicate(format: "publicKey != %@", BotService.shared.findFriendBot.publicKey),
//            NSPredicate(format: "publicKey != %@", BotService.shared.offlineBot.publicKey),
//            NSPredicate(format: "publicKey != %@", BotService.shared.fileBot.publicKey),
//            NSPredicate(format: "friendState == %d", 0),
//            ])
//        let rlmResults = objects(for: .friend, predicate: withoutBotsPredicate)!
//        return Results(results: rlmResults)
//    }
//    
//    func normalChats(predicate: NSPredicate? = nil) -> Results<OCTChat> {
//        var predicates: [NSPredicate] = []
//        if let groupBot = objects(for: .friend, predicate: NSPredicate(format: "publicKey == %@", BotService.shared.groupBot.publicKey))?.firstObject() as? OCTFriend {
//            let withoutBotsPredicate = NSPredicate(format: "ANY friends == %@ AND isGroup == NO", groupBot)
//            predicates.append(NSCompoundPredicate(notPredicateWithSubpredicate: withoutBotsPredicate))
//        }
//        if let findFriendBot = objects(for: .friend, predicate: NSPredicate(format: "publicKey == %@", BotService.shared.findFriendBot.publicKey))?.firstObject() as? OCTFriend {
//            let withoutBotsPredicate = NSPredicate(format: "ANY friends == %@ AND isGroup == NO", findFriendBot)
//            predicates.append(NSCompoundPredicate(notPredicateWithSubpredicate: withoutBotsPredicate))
//        }
//        if let predicate = predicate {
//            predicates.append(predicate)
//        }
//        let rlmResults = objects(for: .chat, predicate: NSCompoundPredicate(andPredicateWithSubpredicates: predicates))!
//        return Results(results: rlmResults)
//    }
//}

extension OCTSubmanagerObjects {
    func friends(predicate: NSPredicate? = nil) -> Results<OCTFriend> {
        let rlmResults = objects(for: .friend, predicate: predicate)!
        return Results(results: rlmResults)
    }

    func friendRequests(predicate: NSPredicate? = nil) -> Results<OCTFriendRequest> {
        let rlmResults = objects(for: .friendRequest, predicate: predicate)!
        return Results(results: rlmResults)
    }

    func chats(predicate: NSPredicate? = nil) -> Results<OCTChat> {
        let rlmResults = objects(for: .chat, predicate: predicate)!
        return Results(results: rlmResults)
    }
    
    func peers(predicate: NSPredicate? = nil) -> Results<OCTPeer> {
        let rlmResults = objectsForPeers(with: predicate)!
        return Results(results: rlmResults)
    }

    func calls(predicate: NSPredicate? = nil) -> Results<OCTCall> {
        let rlmResults = objects(for: .call, predicate: predicate)!
        return Results(results: rlmResults)
    }

    func messages(predicate: NSPredicate? = nil) -> Results<OCTMessageAbstract> {
        let rlmResults = objects(for: .messageAbstract, predicate: predicate)!
        return Results(results: rlmResults)
    }

    func getProfileSettings() -> ProfileSettings {
        guard let data = self.genericSettingsData else {
            return ProfileSettings()
        }

        let unarchiver = NSKeyedUnarchiver(forReadingWith: data)
        let settings =  ProfileSettings(coder: unarchiver)
        unarchiver.finishDecoding()

        return settings
    }

    func saveProfileSettings(_ settings: ProfileSettings) {
        let data = NSMutableData()
        let archiver = NSKeyedArchiver(forWritingWith: data)

        settings.encode(with: archiver)
        archiver.finishEncoding()

        self.genericSettingsData = data.copy() as? Data
    }
}
