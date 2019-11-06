// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "OCTSubmanagerChats.h"
#import "OCTSubmanagerProtocol.h"

@interface OCTSubmanagerChatsImpl : NSObject <OCTSubmanagerChats, OCTSubmanagerProtocol>

@property (nonatomic, strong, readonly) NSOperationQueue *sendMessageQueue;

@end
