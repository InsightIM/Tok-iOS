// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "OCTObject.h"
#import "OCTManagerConstants.h"

@interface OCTMessageCall : OCTObject

/**
 * The length of the call in seconds.
 **/
@property  NSTimeInterval callDuration;

/**
 * The type of message call.
 **/
@property  OCTMessageCallEvent callEvent;

@end
