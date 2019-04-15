// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

extension OCTManagerConfiguration {
    static func configurationWithBaseDirectory(_ baseDirectory: String, profileName: String) -> OCTManagerConfiguration? {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: baseDirectory, isDirectory:&isDirectory)

        guard exists && isDirectory.boolValue else {
            return nil
        }

        let configuration = OCTManagerConfiguration.defaultConfigureation()

//        let userDefaultsManager = UserDefaultsManager()

        configuration.options.ipv6Enabled = true
        configuration.options.udpEnabled = true //userDefaultsManager.UDPEnabled

        configuration.fileStorage = OCTDefaultFileStorage(toxSaveFileName: profileName, baseDirectory: baseDirectory, temporaryDirectory: NSTemporaryDirectory())

        return configuration
    }
    
    static func defaultConfigureation() -> OCTManagerConfiguration {
        let configuration = OCTManagerConfiguration()
        configuration.options = OCTToxOptions()
        configuration.importToxSaveFromPath = nil
        configuration.useFauxOfflineMessaging = true
        return configuration
    }
}

class UserDefaultsManager {
    var lastActiveProfile: String? {
        get {
            return stringForKey(Keys.LastActiveProfile)
        }
        set {
            setObject(newValue as AnyObject?, forKey: Keys.LastActiveProfile)
        }
    }
    
    var UDPEnabled: Bool {
        get {
            return boolForKey(Keys.UDPEnabled, defaultValue: false)
        }
        set {
            setBool(newValue, forKey: Keys.UDPEnabled)
        }
    }
    
    var showNotificationPreview: Bool {
        get {
            return boolForKey(Keys.ShowNotificationsPreview, defaultValue: true)
        }
        set {
            setBool(newValue, forKey: Keys.ShowNotificationsPreview)
        }
    }
    
    var autodownloadFiles: Bool {
        get {
            return boolForKey(Keys.AutodownloadFiles, defaultValue: false)
        }
        set {
            setBool(newValue, forKey: Keys.AutodownloadFiles)
        }
    }
    
    enum AutodownloadImages: String {
        case Never
        case UsingWiFi
        case Always
    }
    
    var autodownloadImages: AutodownloadImages {
        get {
            let defaultValue = AutodownloadImages.Never
            
            guard let string = stringForKey(Keys.AutodownloadImages) else {
                return defaultValue
            }
            return AutodownloadImages(rawValue: string) ?? defaultValue
        }
        set {
            setObject(newValue.rawValue as AnyObject?, forKey: Keys.AutodownloadImages)
        }
    }
    
    var showFindFriendBotTip: Bool {
        get {
            return boolForKey(Keys.ShowFindFriendBotTip, defaultValue: true)
        }
        set {
            setBool(newValue, forKey: Keys.ShowFindFriendBotTip)
            NotificationCenter.default.post(name: NSNotification.Name.FindFriendBotTipChanged, object: newValue)
        }
    }
    
    var showOnboarding: Bool {
        get {
            return boolForKey(Keys.ShowOnboarding, defaultValue: true)
        }
        set {
            setBool(newValue, forKey: Keys.ShowOnboarding)
        }
    }
        
    func resetUDPEnabled() {
        removeObjectForKey(Keys.UDPEnabled)
    }
}

extension NSNotification.Name {
    static let FindFriendBotTipChanged = NSNotification.Name("FindFriendBotTipChanged")
}

private extension UserDefaultsManager {
    struct Keys {
        static let LastActiveProfile = "user-info/last-active-profile"
        static let UDPEnabled = "user-info/udp-enabled"
        static let ShowNotificationsPreview = "user-info/snow-notification-preview"
        static let AutodownloadImages = "user-info/autodownload-images"
        static let AutodownloadFiles = "user-info/autodownload-files"
        static let ShowFindFriendBotTip = "user-info/show-find-friend-tip"
        static let ShowOnboarding = "user-info/show-onboarding"
    }
    
    func setObject(_ object: AnyObject?, forKey key: String) {
        let defaults = UserDefaults.standard
        defaults.set(object, forKey:key)
        defaults.synchronize()
    }
    
    func stringForKey(_ key: String) -> String? {
        let defaults = UserDefaults.standard
        return defaults.string(forKey: key)
    }
    
    func setBool(_ value: Bool, forKey key: String) {
        let defaults = UserDefaults.standard
        defaults.set(value, forKey: key)
        defaults.synchronize()
    }
    
    func boolForKey(_ key: String, defaultValue: Bool) -> Bool {
        let defaults = UserDefaults.standard
        
        if let result = defaults.object(forKey: key) {
            return (result as AnyObject).boolValue
        }
        else {
            return defaultValue
        }
    }
    
    func removeObjectForKey(_ key: String) {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: key)
        defaults.synchronize()
    }
}
