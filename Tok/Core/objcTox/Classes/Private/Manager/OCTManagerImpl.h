// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import <Foundation/Foundation.h>
#import "OCTManager.h"
#import "OCTSubmanagerDataSource.h"

NS_ASSUME_NONNULL_BEGIN

@class OCTManagerConfiguration;
@class OCTTox;
@class OCTToxEncryptSave;
@class OCTRealmManager;
@protocol OCTToxDelegate;

@interface OCTManagerImpl : NSObject <OCTManager>

- (instancetype)initWithConfiguration:(OCTManagerConfiguration *)configuration
                                  tox:(OCTTox *)tox
                       toxEncryptSave:(OCTToxEncryptSave *)toxEncryptSave
                         realmManager:(OCTRealmManager *)realmManager
                             delegate:(id<OCTToxDelegate>)delegate;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
