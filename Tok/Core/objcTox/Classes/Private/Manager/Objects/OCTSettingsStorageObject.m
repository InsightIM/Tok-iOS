// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "OCTSettingsStorageObject.h"

@implementation OCTSettingsStorageObject

+ (NSDictionary *)defaultPropertyValues
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:[super defaultPropertyValues]];

    dict[@"bootstrapDidConnect"] = @NO;
    return [dict copy];
}

@end
