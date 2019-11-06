// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "OCTFileBaseOperation.h"
#import "OCTFileBaseOperation+Private.h"
#import "OCTLogging.h"

#import <QuartzCore/QuartzCore.h>

static const CFTimeInterval kMinUpdateProgressInterval = 0.1;
static const CFTimeInterval kMinUpdateEtaInterval = 1.0;
static const CFTimeInterval kTimeoutInterval = 20;

@interface OCTEtaObject : NSObject
@property (assign, nonatomic) CFTimeInterval deltaTime;
@property (assign, nonatomic) OCTToxFileSize deltaBytes;
@end

@implementation OCTEtaObject
@end

@interface OCTFileBaseOperation ()

@property (assign, atomic) BOOL privateExecuting;
@property (assign, atomic) BOOL privateFinished;

@property (weak, nonatomic, readonly, nullable) OCTTox *tox;

@property (assign, nonatomic, readonly) OCTToxFriendNumber friendNumber;
@property (assign, nonatomic, readwrite) OCTToxFileNumber fileNumber;
@property (assign, nonatomic, readonly) OCTToxFileSize fileSize;

@property (assign, nonatomic, readwrite) OCTToxFileSize bytesDone;
@property (assign, nonatomic, readwrite) float progress;
@property (assign, nonatomic, readwrite) OCTToxFileSize bytesPerSecond;
@property (assign, nonatomic, readwrite) CFTimeInterval eta;

@property (copy, nonatomic) OCTFileBaseOperationProgressBlock progressBlock;
@property (copy, nonatomic) OCTFileBaseOperationProgressBlock etaUpdateBlock;
@property (copy, nonatomic) OCTFileBaseOperationSuccessBlock successBlock;
@property (copy, nonatomic) OCTFileBaseOperationFailureBlock failureBlock;

@property (assign, nonatomic) CFTimeInterval lastUpdateProgressTime;
@property (assign, nonatomic) OCTToxFileSize lastUpdateBytesDone;
@property (assign, nonatomic) CFTimeInterval lastUpdateEtaProgressTime;
@property (assign, nonatomic) OCTToxFileSize lastUpdateEtaBytesDone;

@property (strong, nonatomic) NSMutableArray *last10EtaObjects;

@property (strong, nonatomic) NSTimer *timer;

@end

@implementation OCTFileBaseOperation

#pragma mark -  Class methods

+ (NSString *)operationIdFromFileNumber:(OCTToxFileNumber)fileNumber friendNumber:(OCTToxFriendNumber)friendNumber
{
    return [NSString stringWithFormat:@"%d-%d", fileNumber, friendNumber];
}

#pragma mark -  Lifecycle

- (nullable instancetype)initWithTox:(nonnull OCTTox *)tox
                        friendNumber:(OCTToxFriendNumber)friendNumber
                          fileNumber:(OCTToxFileNumber)fileNumber
                            fileSize:(OCTToxFileSize)fileSize
                            userInfo:(NSDictionary *)userInfo
                       progressBlock:(nullable OCTFileBaseOperationProgressBlock)progressBlock
                      etaUpdateBlock:(nullable OCTFileBaseOperationProgressBlock)etaUpdateBlock
                        successBlock:(nullable OCTFileBaseOperationSuccessBlock)successBlock
                        failureBlock:(nullable OCTFileBaseOperationFailureBlock)failureBlock
{
    NSParameterAssert(tox);

    self = [super init];

    if (! self) {
        return nil;
    }

    _operationId = [[self class] operationIdFromFileNumber:fileNumber friendNumber:friendNumber];

    _tox = tox;

    _friendNumber = friendNumber;
    _fileNumber = fileNumber;
    _fileSize = fileSize;

    _progress = 0.0;
    _bytesPerSecond = 0;
    _eta = 0;

    _userInfo = userInfo;

    _progressBlock = [progressBlock copy];
    _etaUpdateBlock = [etaUpdateBlock copy];
    _successBlock = [successBlock copy];
    _failureBlock = [failureBlock copy];

    _bytesDone = 0;
    _lastUpdateProgressTime = 0;

    return self;
}

- (void)dealloc
{
    [_timer invalidate];
    OCTLogInfo(@"👍👍👍===== %@ %@ dealloc =====👍👍👍", self, self.operationId);
}

- (void)startTimeout
{
    self.lastUpdateProgressTime = CACurrentMediaTime();
    self.lastUpdateBytesDone = 0;
    self.lastUpdateEtaProgressTime = CACurrentMediaTime();
    self.lastUpdateEtaBytesDone = 0;
    self.last10EtaObjects = [NSMutableArray new];
    
    __weak OCTFileBaseOperation *weakSelf = self;
    _timer = [NSTimer scheduledTimerWithTimeInterval:2 repeats:YES block:^(NSTimer * _Nonnull timer) {
        if (weakSelf == nil || weakSelf.isFinished) {
            [timer invalidate];
            return;
        }
        
        CFTimeInterval time = CACurrentMediaTime();
        CFTimeInterval deltaTime = time - weakSelf.lastUpdateProgressTime;
        
        if (deltaTime > kTimeoutInterval) {
            [weakSelf cancel];
            [timer invalidate];
        }
    }];
    
    [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
    
    OCTLogInfo(@"start loading file with identifier %@", self.operationId);
}

#pragma mark -  Properties

- (void)setFileNumber:(OCTToxFileNumber)fileNumber
{
    _fileNumber = fileNumber;
    _operationId = [[self class] operationIdFromFileNumber:fileNumber friendNumber:_friendNumber];
}

- (void)setExecuting:(BOOL)executing
{
    [self willChangeValueForKey:@"isExecuting"];
    self.privateExecuting = executing;
    [self didChangeValueForKey:@"isExecuting"];
}

- (BOOL)isExecuting
{
    return self.privateExecuting;
}

- (void)setFinished:(BOOL)finished
{
    [self willChangeValueForKey:@"isFinished"];
    self.privateFinished = finished;
    [self didChangeValueForKey:@"isFinished"];
}

- (BOOL)isFinished
{
    return self.privateFinished;
}

#pragma mark -  Private category

- (void)updateBytesDone:(OCTToxFileSize)bytesDone
{
    self.bytesDone = bytesDone;

    [self updateProgressIfNeeded:bytesDone];
    [self updateEtaIfNeeded:bytesDone];
}

- (void)operationStarted
{
}

- (void)operationWasCanceled
{
    OCTLogInfo(@"was cancelled");
}

- (void)finishWithSuccess
{
    OCTLogInfo(@"finished with success");

    self.executing = NO;
    self.finished = YES;

    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.successBlock) {
            self.successBlock(self);
        }
    });
}

- (void)finishWithError:(nonnull NSError *)error
{
    NSParameterAssert(error);

    OCTLogInfo(@"finished with error %@", error);

    self.executing = NO;
    self.finished = YES;

    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.failureBlock) {
            self.failureBlock(self, error);
        }
    });
}

#pragma mark -  Override

- (void)start
{
    if (self.cancelled) {
        self.finished = YES;
        return;
    }

    self.executing = YES;

    [self operationStarted];
}

- (void)cancel
{
    [super cancel];

    [self operationWasCanceled];

    self.executing = NO;
    self.finished = YES;
}

- (BOOL)asynchronous
{
    return YES;
}

#pragma mark -  Private

- (void)updateProgressIfNeeded:(OCTToxFileSize)bytesDone
{
    CFTimeInterval time = CACurrentMediaTime();

    CFTimeInterval deltaTime = time - self.lastUpdateProgressTime;

    if (deltaTime <= kMinUpdateProgressInterval) {
        return;
    }

    self.lastUpdateProgressTime = time;
    self.lastUpdateBytesDone = bytesDone;

    self.progress = (float)bytesDone / self.fileSize;

    OCTLogInfo(@"progress %.2f, bytes per second %lld, eta %.0f seconds", self.progress, self.bytesPerSecond, self.eta);

    if (self.progressBlock) {
        self.progressBlock(self);
    }
}

- (void)updateEtaIfNeeded:(OCTToxFileSize)bytesDone
{
    CFTimeInterval time = CACurrentMediaTime();

    CFTimeInterval deltaTime = time - self.lastUpdateEtaProgressTime;

    if (deltaTime <= kMinUpdateEtaInterval) {
        return;
    }

    OCTToxFileSize deltaBytes = bytesDone - self.lastUpdateEtaBytesDone;
    OCTToxFileSize bytesLeft = self.fileSize - bytesDone;

    self.lastUpdateEtaProgressTime = time;
    self.lastUpdateEtaBytesDone = bytesDone;

    OCTEtaObject *etaObject = [OCTEtaObject new];
    etaObject.deltaTime = deltaTime;
    etaObject.deltaBytes = deltaBytes;

    [self.last10EtaObjects addObject:etaObject];
    if (self.last10EtaObjects.count > 10) {
        [self.last10EtaObjects removeObjectAtIndex:0];
    }

    CFTimeInterval totalDeltaTime = 0.0;
    OCTToxFileSize totalDeltaBytes = 0;

    for (OCTEtaObject *object in self.last10EtaObjects) {
        totalDeltaTime += object.deltaTime;
        totalDeltaBytes += object.deltaBytes;
    }

    self.bytesPerSecond = totalDeltaBytes / totalDeltaTime;

    if (totalDeltaBytes) {
        self.eta = totalDeltaTime * bytesLeft / totalDeltaBytes;
    }

    if (self.etaUpdateBlock) {
        self.etaUpdateBlock(self);
    }
}

@end
