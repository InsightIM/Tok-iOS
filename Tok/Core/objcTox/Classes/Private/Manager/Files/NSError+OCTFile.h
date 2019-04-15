// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import <Foundation/Foundation.h>
#import "OCTToxConstants.h"

@class OCTMessageAbstract;

@interface NSError (OCTFile)

+ (NSError *)sendFileErrorInternalError;
+ (NSError *)sendFileErrorCannotReadFile;
+ (NSError *)sendFileErrorCannotSaveFileToUploads;
+ (NSError *)sendFileErrorFriendNotFound;
+ (NSError *)sendFileErrorFriendNotConnected;
+ (NSError *)sendFileErrorNameTooLong;
+ (NSError *)sendFileErrorTooMany;
+ (NSError *)sendFileErrorFromToxFileSendError:(OCTToxErrorFileSend)code;

+ (NSError *)acceptFileErrorInternalError;
+ (NSError *)acceptFileErrorCannotWriteToFile;
+ (NSError *)acceptFileErrorFriendNotFound;
+ (NSError *)acceptFileErrorFriendNotConnected;
+ (NSError *)acceptFileErrorWrongMessage:(OCTMessageAbstract *)message;
+ (NSError *)acceptFileErrorFromToxFileSendChunkError:(OCTToxErrorFileSendChunk)code;
+ (NSError *)acceptFileErrorFromToxFileControl:(OCTToxErrorFileControl)code;

+ (NSError *)fileTransferErrorWrongMessage:(OCTMessageAbstract *)message;

@end
