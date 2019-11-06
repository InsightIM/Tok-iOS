// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import <Foundation/Foundation.h>

@class OCTMessageAbstract;
@class OCTChat;
@protocol OCTSubmanagerFilesProgressSubscriber;

@protocol OCTSubmanagerFiles <NSObject>

/**
 * Send given data to particular chat. After sending OCTMessageAbstract with messageFile will be added to this chat.
 * You can monitor progress using this message.
 *
 * File will be saved in uploaded files directory (see OCTFileStorageProtocol).
 *
 * @param data Data to send.
 * @param fileName Name of the file.
 * @param chat Chat to send data to.
 * @param failureBlock Block that will be called in case of upload failure.
 *     error If an error occurs, this pointer is set to an actual error object containing the error information.
 *     See OCTSendFileError for all error codes.
 */
- (void)sendData:(nonnull NSData *)data
    withFileName:(nonnull NSString *)fileName
          toChat:(nonnull OCTChat *)chat
    failureBlock:(nullable void (^)(NSError *__nonnull error))failureBlock;

/**
 * Send given file to particular chat. After sending OCTMessageAbstract with messageFile will be added to this chat.
 * You can monitor progress using this message.
 *
 * @param filePath Path of file to upload.
 * @param moveToUploads If YES file will be moved to uploads directory.
 * @param chat Chat to send file to.
 * @param failureBlock Block that will be called in case of upload failure.
 *     error If an error occurs, this pointer is set to an actual error object containing the error information.
 *     See OCTSendFileError for all error codes.
 */
- (void)sendFileAtPath:(nonnull NSString *)filePath
              fileName:(NSString *_Nonnull)fileName
         moveToUploads:(BOOL)moveToUploads
                toChat:(nonnull OCTChat *)chat
          failureBlock:(nullable void (^)(NSError *__nonnull error))failureBlock;

/**
 * Accept file transfer.
 *
 * @param message Message with file transfer. Message should be incoming and have OCTMessageFile with
 * fileType OCTMessageFileTypeWaitingConfirmation. Otherwise nothing will happen.
 * @param failureBlock Block that will be called in case of download failure.
 *     error If an error occurs, this pointer is set to an actual error object containing the error information.
 *     See OCTAcceptFileError for all error codes.
 */
- (void)acceptFileTransfer:(nonnull OCTMessageAbstract *)message
              failureBlock:(nullable void (^)(NSError *__nonnull error))failureBlock;

/**
 * Cancel file transfer. File transfer can be waiting confirmation or active.
 *
 * @param message Message with file transfer. Message should have OCTMessageFile. Otherwise nothing will happen.
 */
- (BOOL)cancelFileTransfer:(nonnull OCTMessageAbstract *)message error:(NSError *__nullable *__nullable)error;

/**
 * Retry to send file using same OCTMessageAbstract. This message should have Canceled type, otherwise retry will failure.
 *
 * @param message File transfer message to send.
 * @param failureBlock Block that will be called in case of upload failure.
 *     error If an error occurs, this pointer is set to an actual error object containing the error information.
 *     See OCTSendFileError for all error codes.
 */
- (void)retrySendingFile:(nonnull OCTMessageAbstract *)message
            failureBlock:(nullable void (^)(NSError *__nonnull error))failureBlock;

/**
 * Pause or resume file transfer.
 * - For pausing transfer should be in Loading state or paused by friend, otherwise nothing will happen.
 * - For resuming transfer should be in Paused state and paused by user, otherwise nothing will happen.
 *
 * @param pause Flag notifying of pausing/resuming file transfer.
 * @param message Message with file transfer. Message should have OCTMessageFile.
 * @param error If an error occurs, this pointer is set to an actual error object containing the error information.
 * See OCTFileTransferError for all error codes.
 *
 * @return YES on success, NO on failure.
 */
- (BOOL)pauseFileTransfer:(BOOL)pause
                  message:(nonnull OCTMessageAbstract *)message
                    error:(NSError *__nullable *__nullable)error;

/**
 * Add progress subscriber for given file transfer. Subscriber will receive progress immediately after subscribing.
 * File transfer should be in Loading or Paused state, otherwise subscriber won't be added.
 *
 * @param subscriber Object listening to progress protocol.
 * @param message Message with file transfer. Message should have OCTMessageFile. Otherwise nothing will happen.
 * @param error If an error occurs, this pointer is set to an actual error object containing the error information.
 * See OCTFileTransferError for all error codes.
 *
 * @return YES on success, NO on failure.
 *
 * @warning Subscriber will be stored as weak reference, so it is safe to dealloc it without unsubscribing.
 */
- (BOOL)addProgressSubscriber:(nonnull id<OCTSubmanagerFilesProgressSubscriber>)subscriber
              forFileTransfer:(nonnull OCTMessageAbstract *)message
                        error:(NSError *__nullable *__nullable)error;

/**
 * Remove progress subscriber for given file transfer.
 *
 * @param subscriber Object listening to progress protocol.
 * @param message Message with file transfer. Message should have OCTMessageFile. Otherwise nothing will happen.
 * @param error If an error occurs, this pointer is set to an actual error object containing the error information.
 * See OCTFileTransferError for all error codes.
 *
 * @return YES on success, NO on failure.
 */
- (BOOL)removeProgressSubscriber:(nonnull id<OCTSubmanagerFilesProgressSubscriber>)subscriber
                 forFileTransfer:(nonnull OCTMessageAbstract *)message
                           error:(NSError *__nullable *__nullable)error;

- (void)scheduleFilesCleanup;

- (void)removeAllFileMessages;

@end
