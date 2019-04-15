// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "OCTSubmanagerCalls.h"
#import "OCTSubmanagerProtocol.h"
#import "OCTToxAV.h"
#import "OCTManagerConstants.h"
#import "OCTAudioEngine.h"
#import "OCTVideoEngine.h"
#import "OCTRealmManager.h"
#import "OCTCall+Utilities.h"
#import "OCTCallTimer.h"

@class OCTTox;

@interface OCTSubmanagerCallsImpl : NSObject <OCTSubmanagerCalls, OCTSubmanagerProtocol>

/**
 * Initialize the OCTSubmanagerCall
 */
- (instancetype)initWithTox:(OCTTox *)tox;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end
