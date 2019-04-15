// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "OCTToxConstants.h"
#import "tox.h"

const OCTToxFriendNumber kOCTToxFriendNumberFailure = UINT32_MAX;
const OCTToxFileNumber kOCTToxFileNumberFailure = UINT32_MAX;
const OCTToxFileSize kOCTToxFileSizeUnknown = UINT64_MAX;

NSString *const kOCTToxErrorDomain = @"im.insight.OCTToxErrorDomain";

const NSUInteger kOCTToxAddressLength = 2 * TOX_ADDRESS_SIZE;
const NSUInteger kOCTToxPublicKeyLength = 2 * TOX_PUBLIC_KEY_SIZE;
const NSUInteger kOCTToxSecretKeyLength = 2 * TOX_SECRET_KEY_SIZE;
const NSUInteger kOCTToxMaxNameLength = TOX_MAX_NAME_LENGTH;
const NSUInteger kOCTToxMaxStatusMessageLength = TOX_MAX_STATUS_MESSAGE_LENGTH;
const NSUInteger kOCTToxMaxFriendRequestLength = TOX_MAX_FRIEND_REQUEST_LENGTH;
const NSUInteger kOCTToxMaxMessageLength = TOX_MAX_MESSAGE_LENGTH;
const NSUInteger kOCTToxMaxCustomPacketSize = TOX_MAX_CUSTOM_PACKET_SIZE;
const NSUInteger kOCTToxMaxFileNameLength = TOX_MAX_FILENAME_LENGTH;

const NSUInteger kOCTToxHashLength = TOX_HASH_LENGTH;
const NSUInteger kOCTToxFileIdLength = TOX_FILE_ID_LENGTH;
