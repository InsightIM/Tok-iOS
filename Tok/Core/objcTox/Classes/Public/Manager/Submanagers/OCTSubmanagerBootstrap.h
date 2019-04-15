// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import <Foundation/Foundation.h>

#import "OCTToxConstants.h"

NS_ASSUME_NONNULL_BEGIN

@protocol OCTSubmanagerBootstrap <NSObject>

/**
 * Add node to bootstrap with.
 *
 * This will NOT start bootstrapping. To start actual bootstrapping set all desired nodes
 * and call `bootstrap` method.
 *
 * @param ipv4Host IPv4 hostname or an IP address of the node.
 * @param ipv6Host IPv4 hostname or an IP address of the node.
 * @param udpPort The port on the host on which the bootstrap Tox instance is listening.
 * @param tcpPorts NSNumbers with OCTToxPorts on which the TCP relay is listening.
 * @param publicKey Public key of the node (of kOCTToxPublicKeyLength length).
 */
- (void)addNodeWithIpv4Host:(nullable NSString *)ipv4Host
                   ipv6Host:(nullable NSString *)ipv6Host
                    udpPort:(OCTToxPort)udpPort
                   tcpPorts:(NSArray<NSNumber *> *)tcpPorts
                  publicKey:(NSString *)publicKey;

/**
 * Add nodes from https://nodes.tox.chat/. objcTox is trying to keep this list up to date.
 * You can check all nodes and update date in nodes.json file.
 *
 * This will NOT start bootstrapping. To start actual bootstrapping set all desired nodes
 * and call `bootstrap` method.
 */
- (void)addPredefinedNodes;

/**
 * You HAVE TO call this method on startup to connect to Tox network.
 *
 * Before calling this method add nodes to bootstrap with.
 *
 * After calling this method
 * - if manager wasn't connected before it will start bootstrapping immediately.
 * - if it was connected before, it will wait 10 to connect to existing nodes
 *   before starting actually bootstrapping.
 *
 * When bootstrapping, submanager will bootstrap 4 random nodes from a list every 5 seconds
 * until is will be connected.
 */
- (void)bootstrap;

@end

NS_ASSUME_NONNULL_END
