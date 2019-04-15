// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import <Foundation/Foundation.h>
#import "OCTToxConstants.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * After creation OCTToxOptions will have predefined default values.
 */
@interface OCTToxOptions : NSObject <NSCopying>

/**
 * The type of socket to create.
 *
 * If this is set to false, an IPv4 socket is created, which subsequently
 * only allows IPv4 communication.
 * If it is set to true, an IPv6 socket is created, allowing both IPv4 and
 * IPv6 communication.
 */
@property (nonatomic, assign) BOOL ipv6Enabled;

/**
 * Enable the use of UDP communication when available.
 *
 * Setting this to false will force Tox to use TCP only. Communications will
 * need to be relayed through a TCP relay node, potentially slowing them down.
 * Disabling UDP support is necessary when using anonymous proxies or Tor.
 */
@property (nonatomic, assign) BOOL udpEnabled;

/**
 * Enable local network peer discovery.
 *
 * Disabling this will cause Tox to not look for peers on the local network.
 */
@property (nonatomic, assign) BOOL localDiscoveryEnabled;

/**
 * Pass communications through a proxy.
 */
@property (nonatomic, assign) OCTToxProxyType proxyType;

/**
 * The IP address or DNS name of the proxy to be used.
 *
 * If used, this must be non-NULL and be a valid DNS name. The name must not
 * exceed 255 characters.
 *
 * This member is ignored (it can be nil) if proxyType is OCTToxProxyTypeNone.
 */
@property (nonatomic, copy, nullable) NSString *proxyHost;

/**
 * The port to use to connect to the proxy server.
 *
 * Ports must be in the range (1, 65535). The value is ignored if
 * proxyType is OCTToxProxyTypeNone.
 */
@property (nonatomic, assign) uint16_t proxyPort;

/**
 * The start port of the inclusive port range to attempt to use.
 *
 * If both start_port and end_port are 0, the default port range will be
 * used: [33445, 33545].
 *
 * If either start_port or end_port is 0 while the other is non-zero, the
 * non-zero port will be the only port in the range.
 *
 * Having start_port > end_port will yield the same behavior as if start_port
 * and end_port were swapped.
 */
@property (nonatomic, assign) uint16_t startPort;

/**
 * The end port of the inclusive port range to attempt to use.
 */
@property (nonatomic, assign) uint16_t endPort;

/**
 * The port to use for the TCP server (relay). If 0, the TCP server is
 * disabled.
 *
 * Enabling it is not required for Tox to function properly.
 *
 * When enabled, your Tox instance can act as a TCP relay for other Tox
 * instance. This leads to increased traffic, thus when writing a client
 * it is recommended to enable TCP server only if the user has an option
 * to disable it.
 */
@property (nonatomic, assign) uint16_t tcpPort;

/**
 * Enables or disables UDP hole-punching in toxcore. (Default: enabled).
 */
@property (nonatomic, assign) BOOL holePunchingEnabled;

@end

NS_ASSUME_NONNULL_END
