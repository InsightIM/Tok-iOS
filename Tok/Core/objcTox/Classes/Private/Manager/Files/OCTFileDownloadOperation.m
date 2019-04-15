// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "OCTFileDownloadOperation.h"
#import "OCTFileBaseOperation+Private.h"
#import "OCTFileOutputProtocol.h"
#import "OCTLogging.h"
#import "NSError+OCTFile.h"

@interface OCTFileDownloadOperation ()

@end

@implementation OCTFileDownloadOperation

#pragma mark -  Lifecycle

- (nullable instancetype)initWithTox:(nonnull OCTTox *)tox
                          fileOutput:(nonnull id<OCTFileOutputProtocol>)fileOutput
                        friendNumber:(OCTToxFriendNumber)friendNumber
                          fileNumber:(OCTToxFileNumber)fileNumber
                            fileSize:(OCTToxFileSize)fileSize
                            userInfo:(NSDictionary *)userInfo
                       progressBlock:(nullable OCTFileBaseOperationProgressBlock)progressBlock
                      etaUpdateBlock:(nullable OCTFileBaseOperationProgressBlock)etaUpdateBlock
                        successBlock:(nullable OCTFileBaseOperationSuccessBlock)successBlock
                        failureBlock:(nullable OCTFileBaseOperationFailureBlock)failureBlock
{
    NSParameterAssert(fileOutput);

    self = [super initWithTox:tox
                 friendNumber:friendNumber
                   fileNumber:fileNumber
                     fileSize:fileSize
                     userInfo:userInfo
                progressBlock:progressBlock
               etaUpdateBlock:etaUpdateBlock
                 successBlock:successBlock
                 failureBlock:failureBlock];

    if (! self) {
        return nil;
    }

    _output = fileOutput;

    return self;
}

#pragma mark -  Public

- (void)receiveChunk:(NSData *)chunk position:(OCTToxFileSize)position
{
    if (! chunk) {
        if ([self.output finishWriting]) {
            [self finishWithSuccess];
        }
        else {
            [self finishWithError:[NSError acceptFileErrorCannotWriteToFile]];
        }
        return;
    }

    if (self.bytesDone != position) {
        OCTLogWarn(@"bytesDone doesn't match position");
        [self.tox fileSendControlForFileNumber:self.fileNumber
                                  friendNumber:self.friendNumber
                                       control:OCTToxFileControlCancel
                                         error:nil];
        [self finishWithError:[NSError acceptFileErrorInternalError]];
        return;
    }

    if (! [self.output writeData:chunk]) {
        [self finishWithError:[NSError acceptFileErrorCannotWriteToFile]];
        return;
    }

    [self updateBytesDone:self.bytesDone + chunk.length];
}

#pragma mark -  Override

- (void)operationStarted
{
    [super operationStarted];

    if (! [self.output prepareToWrite]) {
        [self finishWithError:[NSError acceptFileErrorCannotWriteToFile]];
    }

    NSError *error;
    NSLog(@"【fileSendControl】FileNumber: %d,  friendNumber: %d", self.fileNumber, self.friendNumber);
    if (! [self.tox fileSendControlForFileNumber:self.fileNumber
                                    friendNumber:self.friendNumber
                                         control:OCTToxFileControlResume
                                           error:&error]) {
        NSLog(@"cannot send control %@", error);
        [self finishWithError:[NSError acceptFileErrorFromToxFileControl:error.code]];
        return;
    }
}

- (void)operationWasCanceled
{
    [super operationWasCanceled];

    [self.output cancel];
}

@end
