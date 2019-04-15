// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

@class OCTCall;
@protocol OCTSubmanagerCalls;

@protocol OCTSubmanagerCallDelegate <NSObject>

/**
 * This gets called when we receive a call.
 **/
- (void)callSubmanager:(id<OCTSubmanagerCalls>)callSubmanager receiveCall:(OCTCall *)call audioEnabled:(BOOL)audioEnabled videoEnabled:(BOOL)videoEnabled;

@end
