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

        let userDefaultsManager = UserDefaultsManager()

        configuration.options.ipv6Enabled = true
        configuration.options.udpEnabled = userDefaultsManager.UDPEnabled
        configuration.options.localDiscoveryEnabled = true
        
        if userDefaultsManager.proxyEnabled, let proxy = ProxyModel.retrieve().first(where: { $0.selected }) {
            configuration.options.proxyHost = proxy.server
            configuration.options.proxyPort = UInt16(proxy.port)
            configuration.options.proxyType = .socks5
        }

        configuration.fileStorage = OCTDefaultFileStorage(toxSaveFileName: profileName, baseDirectory: baseDirectory, temporaryDirectory: NSTemporaryDirectory())
        configuration.options.deviceType = 1;
        
        let versionString = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let versions = versionString?.split(separator: ".").map { UInt32($0) }.compactMap { $0 }
        if let versions = versions, versions.count == 3 {
            configuration.options.versionCode = (versions[0] * 10000 + versions[1] * 100 + versions[2] * 1)
        } else {
            fatalError("app version wrong")
        }

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

@objc
class UserDefaultsManager: NSObject {
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
            return boolForKey(Keys.UDPEnabled, defaultValue: true)
        }
        set {
            setBool(newValue, forKey: Keys.UDPEnabled)
        }
    }
    
    var CrashEnabled: Bool {
        get {
            return boolForKey(Keys.CrashEnabled, defaultValue: true)
        }
        set {
            setBool(newValue, forKey: Keys.CrashEnabled)
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
            return boolForKey(Keys.AutodownloadFiles, defaultValue: true)
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
    
    enum JoinGroupSetting: String {
        case contacts
        case nobody
    }
    
    var joinGroupSetting: JoinGroupSetting {
        get {
            let defaultValue = JoinGroupSetting.contacts
            
            guard let string = stringForKey(Keys.JoinGroupSetting) else {
                return defaultValue
            }
            return JoinGroupSetting(rawValue: string) ?? defaultValue
        }
        set {
            setObject(newValue.rawValue as AnyObject?, forKey: Keys.JoinGroupSetting)
        }
    }
    
    @objc
    var joinGroupSettingNobody: Bool {
        return joinGroupSetting == .nobody
    }
    
    var newFeatureForWallet: Bool {
        get {
            return boolForKey(Keys.NewFeatureForWallet, defaultValue: true)
         }
         set {
            setBool(newValue, forKey: Keys.NewFeatureForWallet)
         }
     }
    
    var newFeatureForNeverland: Bool {
        get {
            return boolForKey(Keys.NewFeatureForNeverland, defaultValue: true)
        }
        set {
            setBool(newValue, forKey: Keys.NewFeatureForNeverland)
        }
    }
    
    var newFeatureForGroupRecommend: Bool {
        get {
            return boolForKey(Keys.NewFeatureForGroupRecommend, defaultValue: true)
        }
        set {
            setBool(newValue, forKey: Keys.NewFeatureForGroupRecommend)
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
    
    var showNewFeatureOnMe: Bool {
        get {
            return boolForKey(Keys.ShowNewFeatureOnMe, defaultValue: true)
        }
        set {
            setBool(newValue, forKey: Keys.ShowNewFeatureOnMe)
        }
    }
    
    var startFindStranger: Bool {
        get {
            return boolForKey(Keys.StartFindStranger, defaultValue: false)
        }
        set {
            setBool(newValue, forKey: Keys.StartFindStranger)
        }
    }
    
    var proxyEnabled: Bool {
         get {
            return boolForKey(Keys.ProxyEnabled, defaultValue: false)
         }
         set {
            setBool(newValue, forKey: Keys.ProxyEnabled)
         }
     }
    
    var newFeatureForPasscode: Bool {
        get {
            return boolForKey(Keys.userIdKey(Keys.NewFeatureForPasscode), defaultValue: true)
        }
        set {
            setBool(newValue, forKey: Keys.userIdKey(Keys.NewFeatureForPasscode))
        }
    }
    
    var pinEnabled: Bool {
        get {
            return boolForKey(Keys.PinEnabled, defaultValue: false)
        }
        set {
            setBool(newValue, forKey: Keys.PinEnabled)
        }
    }
    
    var quickUnlockEnabled: Bool {
        get {
            return boolForKey(Keys.QuickUnlockEnabled, defaultValue: false)
        }
        set {
            setBool(newValue, forKey: Keys.QuickUnlockEnabled)
        }
    }
    
    var destroyPinEnabled: Bool {
        get {
            return boolForKey(Keys.DestroyPinEnabled, defaultValue: false)
        }
        set {
            setBool(newValue, forKey: Keys.DestroyPinEnabled)
        }
    }
    
    var userPasscode: String {
        get {
            return stringForKey(Keys.UserPasscode) ?? ""
        }
        set {
            setObject(newValue as AnyObject?, forKey: Keys.UserPasscode)
        }
    }
    
    var customBootstrapEnabled: Bool {
         get {
            return boolForKey(Keys.CustomBootstrapEnabled, defaultValue: false)
         }
         set {
            setBool(newValue, forKey: Keys.CustomBootstrapEnabled)
         }
     }
    
    var userDestroyPasscode: String {
        get {
            return stringForKey(Keys.UserDestroyPasscode) ?? ""
        }
        set {
            setObject(newValue as AnyObject?, forKey: Keys.UserDestroyPasscode)
        }
    }
        
    func resetUDPEnabled() {
        removeObjectForKey(Keys.UDPEnabled)
    }
    
    var passcodeRetryErrorTime: Double {
        get {
            return doubleForKey(Keys.userIdKey(Keys.PasscodeRetryErrorTime))
        }
        set {
            setDouble(newValue, forKey: Keys.userIdKey(Keys.PasscodeRetryErrorTime))
        }
    }
    
    var passcodeRetryErrorCount: Int {
        get {
            return integerForKey(Keys.userIdKey(Keys.PasscodeRetryErrorCount))
        }
        set {
            setInteger(newValue, forKey: Keys.userIdKey(Keys.PasscodeRetryErrorCount))
        }
    }
    
    var destroycodeRetryErrorTime: Double {
        get {
            return doubleForKey(Keys.userIdKey(Keys.DestroycodeRetryErrorTime))
        }
        set {
            setDouble(newValue, forKey: Keys.userIdKey(Keys.DestroycodeRetryErrorTime))
        }
    }
    
    var destroycodeRetryErrorCount: Int {
        get {
            return integerForKey(Keys.userIdKey(Keys.DestroycodeRetryErrorCount))
        }
        set {
            setInteger(newValue, forKey: Keys.userIdKey(Keys.DestroycodeRetryErrorCount))
        }
    }
    
    var checkUpdateVersionCode: Int {
        get {
            return integerForKey(Keys.CheckUpdateVersionCode)
        }
        set {
            setInteger(newValue, forKey: Keys.CheckUpdateVersionCode)
        }
    }
    
    var checkUpdateVersion: String {
        get {
            return stringForKey(Keys.CheckUpdateVersion) ?? ""
        }
        set {
            setObject(newValue as AnyObject?, forKey: Keys.CheckUpdateVersion)
        }
    }
    
}

private extension UserDefaultsManager {
    struct Keys {
        static let LastActiveProfile = "user-info/last-active-profile"
        static let UDPEnabled = "user-info/udp-enabled"
        static let CrashEnabled = "user-info/crash-enabled"
        static let ShowNotificationsPreview = "user-info/snow-notification-preview"
        static let AutodownloadImages = "user-info/autodownload-images"
        static let AutodownloadFiles = "user-info/autodownload-files"
        static let NewFeatureForWallet = "user-info/newfeature-for-wallet"
        static let NewFeatureForNeverland = "user-info/newfeature-for-neverland"
        static let NewFeatureForGroupRecommend = "user-info/newfeature-for-grouprecommend"
        static let ShowOnboarding = "user-info/show-onboarding"
        static let ShowNewFeatureOnMe = "user-info/show-new-feature-onme-1.5.0"
        static let StartFindStranger = "user-info/start-find-stranger"
        static let NewFeatureForPasscode = "user-info/newfeature-for-passcode"
        static let PinEnabled = "user-info/pin-enabled"
        static let QuickUnlockEnabled = "user-info/quick-unlock-enabled"
        static let DestroyPinEnabled = "user-info/destroy-pin-enabled"
        static let UserPasscode = "user-info/user-password"
        static let UserDestroyPasscode = "user-info/user-destroy-password"
        static let JoinGroupSetting = "user-info/join-group-setting"
        static let ProxyEnabled = "user-info/proxy-enabled"
        static let CustomBootstrapEnabled = "user-info/custom-bootstrap-enabled"
        static let PasscodeRetryErrorTime = "user-info/passcode-retry-error-time"
        static let PasscodeRetryErrorCount = "user-info/passcode-retry-error-count"
        static let DestroycodeRetryErrorTime = "user-info/destroycode-retry-error-time"
        static let DestroycodeRetryErrorCount = "user-info/destroycode-retry-error-count"
        static let CheckUpdateVersionCode = "user-info/check-update-version-code"
        static let CheckUpdateVersion = "user-info/check-update-version"
        
        static func userIdKey(_ key: String) -> String {
            return key + (UserService.shared.toxMananger?.user.userAddress ?? "")
        }
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
    
    func setDouble(_ value: Double, forKey key: String) {
        let defaults = UserDefaults.standard
        defaults.set(value, forKey: key)
        defaults.synchronize()
    }
    
    func doubleForKey(_ key: String) -> Double {
        let defaults = UserDefaults.standard
        return defaults.double(forKey: key)
    }
    
    func setInteger(_ value: Int, forKey key: String) {
        let defaults = UserDefaults.standard
        defaults.set(value, forKey: key)
        defaults.synchronize()
    }
    
    func integerForKey(_ key: String) -> Int {
        let defaults = UserDefaults.standard
        return defaults.integer(forKey: key)
    }
    
    func removeObjectForKey(_ key: String) {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: key)
        defaults.synchronize()
    }
}
