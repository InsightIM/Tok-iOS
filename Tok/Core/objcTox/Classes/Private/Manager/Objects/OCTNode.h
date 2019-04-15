// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import <Foundation/Foundation.h>

#import "OCTToxConstants.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCTNode : NSObject

@property (copy, nonatomic, readonly, nullable) NSString *ipv4Host;
@property (copy, nonatomic, readonly, nullable) NSString *ipv6Host;
@property (assign, nonatomic, readonly) OCTToxPort udpPort;
@property (copy, nonatomic, readonly) NSArray<NSNumber *> *tcpPorts;
@property (copy, nonatomic, readonly) NSString *publicKey;

- (instancetype)initWithIpv4Host:(nullable NSString *)ipv4Host
                        ipv6Host:(nullable NSString *)ipv6Host
                         udpPort:(OCTToxPort)udpPort
                        tcpPorts:(NSArray<NSNumber *> *)tcpPorts
                       publicKey:(NSString *)publicKey;

- (BOOL)isEqual:(id)object;
- (NSUInteger)hash;

@end

NS_ASSUME_NONNULL_END
