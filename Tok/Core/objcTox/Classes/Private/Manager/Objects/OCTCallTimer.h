// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import <Foundation/Foundation.h>
@class OCTRealmManager;
@class OCTCall;

@interface OCTCallTimer : NSObject

- (instancetype)initWithRealmManager:(OCTRealmManager *)realmManager;

/**
 * Starts the timer for the specified call.
 * Note that there can only be one active call.
 * @param call Call to update.
 */
- (void)startTimerForCall:(OCTCall *)call;

/**
 * Stops the timer for the current call in session.
 */
- (void)stopTimer;

@end
