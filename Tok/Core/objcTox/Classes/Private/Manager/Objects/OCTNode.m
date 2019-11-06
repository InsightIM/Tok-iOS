// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "OCTNode.h"

@implementation OCTNode

#pragma mark -  Lifecycle

- (instancetype)initWithIpv4Host:(nullable NSString *)ipv4Host
                        ipv6Host:(nullable NSString *)ipv6Host
                         udpPort:(OCTToxPort)udpPort
                        tcpPorts:(NSArray<NSNumber *> *)tcpPorts
                       publicKey:(NSString *)publicKey
{
    self = [super init];

    if (! self) {
        return nil;
    }

    _ipv4Host = [ipv4Host copy];
    _ipv6Host = [ipv6Host copy];
    _udpPort = udpPort;
    _tcpPorts = [tcpPorts copy];
    _publicKey = [publicKey copy];

    return self;
}

- (BOOL)isEqual:(id)object
{
    if (! [object isKindOfClass:[OCTNode class]]) {
        return NO;
    }

    OCTNode *another = object;

    return [self compareString:self.ipv4Host with:another.ipv4Host] &&
           [self compareString:self.ipv6Host with:another.ipv6Host] &&
           (self.udpPort == another.udpPort) &&
           [self.tcpPorts isEqual:another.tcpPorts] &&
           [self.publicKey isEqual:another.publicKey];
}

- (NSUInteger)hash
{
    const NSUInteger prime = 31;
    NSUInteger result = 1;

    result = prime * result + [self.ipv4Host hash];
    result = prime * result + [self.ipv6Host hash];
    result = prime * result + self.udpPort;
    result = prime * result + [self.tcpPorts hash];
    result = prime * result + [self.publicKey hash];

    return result;
}

- (BOOL)compareString:(NSString *)first with:(NSString *)second
{
    if (first && second) {
        return [first isEqual:second];
    }

    BOOL bothNil = ! first && ! second;
    return bothNil;
}

@end
