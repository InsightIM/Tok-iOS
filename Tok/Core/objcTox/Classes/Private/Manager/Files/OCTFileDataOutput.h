// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import <Foundation/Foundation.h>
#import "OCTFileOutputProtocol.h"

@interface OCTFileDataOutput : NSObject <OCTFileOutputProtocol>

/**
 * Result data. This property will contain data only after download finishes.
 */
@property (strong, nonatomic, readonly, nullable) NSData *resultData;

@end
