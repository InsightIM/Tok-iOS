// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "NSError+OCTFile.h"
#import "OCTManagerConstants.h"

@implementation NSError (OCTFile)

+ (NSError *)sendFileErrorInternalError
{
    return [NSError errorWithDomain:kOCTManagerErrorDomain
                               code:OCTSendFileErrorInternalError
                           userInfo:@{
                NSLocalizedDescriptionKey : @"Send file",
                NSLocalizedFailureReasonErrorKey : @"Internal error",
            }];
}

+ (NSError *)sendFileErrorCannotReadFile
{
    return [NSError errorWithDomain:kOCTManagerErrorDomain
                               code:OCTSendFileErrorCannotReadFile
                           userInfo:@{
                NSLocalizedDescriptionKey : @"Send file",
                NSLocalizedFailureReasonErrorKey : @"Cannot read file",
            }];
}

+ (NSError *)sendFileErrorCannotSaveFileToUploads
{
    return [NSError errorWithDomain:kOCTManagerErrorDomain
                               code:OCTSendFileErrorCannotSaveFileToUploads
                           userInfo:@{
                NSLocalizedDescriptionKey : @"Send file",
                NSLocalizedFailureReasonErrorKey : @"Cannot save send file to uploads folder.",
            }];
}

+ (NSError *)sendFileErrorFriendNotFound
{
    return [NSError errorWithDomain:kOCTManagerErrorDomain
                               code:OCTSendFileErrorFriendNotFound
                           userInfo:@{
                NSLocalizedDescriptionKey : @"Send file",
                NSLocalizedFailureReasonErrorKey : @"Friend to send file to was not found.",
            }];
}

+ (NSError *)sendFileErrorFriendNotConnected
{
    return [NSError errorWithDomain:kOCTManagerErrorDomain
                               code:OCTSendFileErrorFriendNotConnected
                           userInfo:@{
                NSLocalizedDescriptionKey : @"Send file",
                NSLocalizedFailureReasonErrorKey : @"Friend is not connected at the moment.",
            }];
}

+ (NSError *)sendFileErrorNameTooLong
{
    return [NSError errorWithDomain:kOCTManagerErrorDomain
                               code:OCTSendFileErrorFriendNotConnected
                           userInfo:@{
                NSLocalizedDescriptionKey : @"Send file",
                NSLocalizedFailureReasonErrorKey : @"File name is too long.",
            }];
}

+ (NSError *)sendFileErrorTooMany
{
    return [NSError errorWithDomain:kOCTManagerErrorDomain
                               code:OCTSendFileErrorFriendNotConnected
                           userInfo:@{
                NSLocalizedDescriptionKey : @"Send file",
                NSLocalizedFailureReasonErrorKey : @"Too many active file transfers.",
            }];
}

+ (NSError *)sendFileErrorFromToxFileSendError:(OCTToxErrorFileSend)code
{
    switch (code) {
        case OCTToxErrorFileSendUnknown:
            return [self sendFileErrorInternalError];
        case OCTToxErrorFileSendFriendNotFound:
            return [self sendFileErrorFriendNotFound];
        case OCTToxErrorFileSendFriendNotConnected:
            return [self sendFileErrorFriendNotConnected];
        case OCTToxErrorFileSendNameTooLong:
            return [self sendFileErrorNameTooLong];
        case OCTToxErrorFileSendTooMany:
            return [self sendFileErrorTooMany];
    }
}

+ (NSError *)acceptFileErrorInternalError
{
    return [NSError errorWithDomain:kOCTManagerErrorDomain
                               code:OCTAcceptFileErrorInternalError
                           userInfo:@{
                NSLocalizedDescriptionKey : @"Download file",
                NSLocalizedFailureReasonErrorKey : @"Internal error",
            }];
}

+ (NSError *)acceptFileErrorCannotWriteToFile
{
    return [NSError errorWithDomain:kOCTManagerErrorDomain
                               code:OCTAcceptFileErrorCannotWriteToFile
                           userInfo:@{
                NSLocalizedDescriptionKey : @"Download file",
                NSLocalizedFailureReasonErrorKey : @"File is not available for writing.",
            }];
}

+ (NSError *)acceptFileErrorFriendNotFound
{
    return [NSError errorWithDomain:kOCTManagerErrorDomain
                               code:OCTAcceptFileErrorFriendNotFound
                           userInfo:@{
                NSLocalizedDescriptionKey : @"Download file",
                NSLocalizedFailureReasonErrorKey : @"Friend to send file to was not found.",
            }];
}

+ (NSError *)acceptFileErrorFriendNotConnected
{
    return [NSError errorWithDomain:kOCTManagerErrorDomain
                               code:OCTAcceptFileErrorFriendNotConnected
                           userInfo:@{
                NSLocalizedDescriptionKey : @"Download file",
                NSLocalizedFailureReasonErrorKey : @"Friend is not connected at the moment.",
            }];
}

+ (NSError *)acceptFileErrorWrongMessage:(OCTMessageAbstract *)message
{
    return [NSError errorWithDomain:kOCTManagerErrorDomain
                               code:OCTAcceptFileErrorWrongMessage
                           userInfo:@{
                NSLocalizedDescriptionKey : @"Download file",
                NSLocalizedFailureReasonErrorKey : [NSString stringWithFormat:@"Specified wrong message %@", message],
            }];
}

+ (NSError *)acceptFileErrorFromToxFileSendChunkError:(OCTToxErrorFileSendChunk)code
{
    switch (code) {
        case OCTToxErrorFileSendChunkFriendNotFound:
            return [self acceptFileErrorFriendNotFound];
        case OCTToxErrorFileSendChunkFriendNotConnected:
            return [self acceptFileErrorFriendNotConnected];
        case OCTToxErrorFileSendChunkUnknown:
        case OCTToxErrorFileSendChunkNotFound:
        case OCTToxErrorFileSendChunkNotTransferring:
        case OCTToxErrorFileSendChunkInvalidLength:
        case OCTToxErrorFileSendChunkSendq:
        case OCTToxErrorFileSendChunkWrongPosition:
            return [self acceptFileErrorInternalError];
    }
}

+ (NSError *)acceptFileErrorFromToxFileControl:(OCTToxErrorFileControl)code
{
    switch (code) {
        case OCTToxErrorFileControlFriendNotFound:
            return [self acceptFileErrorFriendNotFound];
        case OCTToxErrorFileControlFriendNotConnected:
            return [self acceptFileErrorFriendNotConnected];
        case OCTToxErrorFileControlNotFound:
        case OCTToxErrorFileControlNotPaused:
        case OCTToxErrorFileControlDenied:
        case OCTToxErrorFileControlAlreadyPaused:
        case OCTToxErrorFileControlSendq:
            return [self acceptFileErrorInternalError];
    }
}

+ (NSError *)fileTransferErrorWrongMessage:(OCTMessageAbstract *)message
{
    return [NSError errorWithDomain:kOCTManagerErrorDomain
                               code:OCTFileTransferErrorWrongMessage
                           userInfo:@{
                NSLocalizedDescriptionKey : @"Error",
                NSLocalizedFailureReasonErrorKey : [NSString stringWithFormat:@"Specified wrong message %@", message],
            }];
}

@end
