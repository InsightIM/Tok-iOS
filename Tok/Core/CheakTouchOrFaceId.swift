//
//  CheakTouchOrFaceId.swift
//  Tok
//
//  Created by lbowen on 2019/9/25.
//  Copyright © 2019 Insight. All rights reserved.
//

import UIKit
import LocalAuthentication

class CheakTouchOrFaceId: NSObject {
    
    class func isSupport() -> (isSupport: Bool, isTouchId: Bool) {
        
        let context = LAContext()
        var error: NSError?
        
        let supportEvaluatePolicy = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        
        if supportEvaluatePolicy {
            
            if #available(iOS 11.0, *) {
                
                if context.biometryType == .touchID {
                    
                    return (true, true)
                } else if context.biometryType == .faceID {
                    
                    return (true, false)
                }
            } else {
                
                guard let laError = error as? LAError else {
                    return (false, false)
                }
                if laError.code != .touchIDNotAvailable {
                    return (true, true)
                }
            }
        }
        
        return (false, false)
    }
}
