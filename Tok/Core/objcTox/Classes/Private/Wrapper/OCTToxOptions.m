// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "OCTToxOptions+Private.h"
#import "tox.h"

@interface OCTToxOptions ()

@property (nonatomic, assign, readonly) struct Tox_Options *options;

// Used to retain proxy_host option.
@property (nonatomic, copy) NSString *proxyHostStorage;

@end

@implementation OCTToxOptions

#pragma mark - Lifecycle

- (instancetype)init
{
    self = [super init];

    if (! self) {
        return nil;
    }

    _options = tox_options_new(NULL);

    return self;
}

- (void)dealloc
{
    tox_options_free(_options);
}

#pragma mark - Description

- (NSString *)description
{
    return [NSString stringWithFormat:@"OCTToxOptions:\n"
            @"ipv6Enabled %d\n"
            @"udpEnabled %d\n"
            @"localDiscoveryEnabled %d\n"
            @"proxyType %lu\n"
            @"proxyHost %@\n"
            @"proxyPort %d\n"
            @"startPort %d\n"
            @"endPort %d\n"
            @"tcpPort %d\n"
            @"holePunchingEnabled %d\n",
            self.ipv6Enabled,
            self.udpEnabled,
            self.localDiscoveryEnabled,
            self.proxyType,
            self.proxyHost,
            self.proxyPort,
            self.startPort,
            self.endPort,
            self.tcpPort,
            self.holePunchingEnabled];
}

#pragma mark - Properties

- (BOOL)ipv6Enabled
{
    return tox_options_get_ipv6_enabled(self.options);
}

- (void)setIpv6Enabled:(BOOL)enabled
{
    tox_options_set_ipv6_enabled(self.options, enabled);
}

- (BOOL)udpEnabled
{
    return tox_options_get_udp_enabled(self.options);
}

- (void)setUdpEnabled:(BOOL)enabled
{
    tox_options_set_udp_enabled(self.options, enabled);
}

- (BOOL)localDiscoveryEnabled
{
    return tox_options_get_local_discovery_enabled(self.options);
}

- (void)setLocalDiscoveryEnabled:(BOOL)enabled
{
    tox_options_set_local_discovery_enabled(self.options, enabled);
}

- (OCTToxProxyType)proxyType
{
    switch (tox_options_get_proxy_type(self.options)) {
        case TOX_PROXY_TYPE_NONE:
            return OCTToxProxyTypeNone;
        case TOX_PROXY_TYPE_HTTP:
            return OCTToxProxyTypeHTTP;
        case TOX_PROXY_TYPE_SOCKS5:
            return OCTToxProxyTypeSocks5;
    }
}

- (void)setProxyType:(OCTToxProxyType)type
{
    switch (type) {
        case OCTToxProxyTypeNone:
            tox_options_set_proxy_type(self.options, TOX_PROXY_TYPE_NONE);
            break;
        case OCTToxProxyTypeHTTP:
            tox_options_set_proxy_type(self.options, TOX_PROXY_TYPE_HTTP);
            break;
        case OCTToxProxyTypeSocks5:
            tox_options_set_proxy_type(self.options, TOX_PROXY_TYPE_SOCKS5);
            break;
    }
}

- (NSString *)proxyHost
{
    const char *cHost = tox_options_get_proxy_host(self.options);

    if (cHost) {
        return [NSString stringWithCString:cHost encoding:NSUTF8StringEncoding];
    }

    return nil;
}

- (void)setProxyHost:(NSString *)host
{
    self.proxyHostStorage = host;
    tox_options_set_proxy_host(self.options, self.proxyHostStorage.UTF8String);
}

- (uint16_t)proxyPort
{
    return tox_options_get_proxy_port(self.options);
}

- (void)setProxyPort:(uint16_t)port
{
    tox_options_set_proxy_port(self.options, port);
}

- (uint16_t)startPort
{
    return tox_options_get_start_port(self.options);
}

- (void)setStartPort:(uint16_t)port
{
    tox_options_set_start_port(self.options, port);
}

- (uint16_t)endPort
{
    return tox_options_get_end_port(self.options);
}

- (void)setEndPort:(uint16_t)port
{
    tox_options_set_end_port(self.options, port);
}

- (uint16_t)tcpPort
{
    return tox_options_get_tcp_port(self.options);
}

- (void)setTcpPort:(uint16_t)port
{
    tox_options_set_tcp_port(self.options, port);
}

- (BOOL)holePunchingEnabled
{
    return tox_options_get_hole_punching_enabled(self.options);
}

- (void)setHolePunchingEnabled:(BOOL)enabled
{
    tox_options_set_hole_punching_enabled(self.options, enabled);
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    OCTToxOptions *options = [[[self class] allocWithZone:zone] init];

    options.ipv6Enabled = self.ipv6Enabled;
    options.udpEnabled = self.udpEnabled;
    options.localDiscoveryEnabled = self.localDiscoveryEnabled;
    options.proxyType = self.proxyType;
    options.proxyHost = self.proxyHost;
    options.proxyPort = self.proxyPort;
    options.startPort = self.startPort;
    options.endPort = self.endPort;
    options.tcpPort = self.tcpPort;
    options.holePunchingEnabled = self.holePunchingEnabled;

    return options;
}

@end
