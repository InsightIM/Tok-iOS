// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "OCTCallTimer.h"
#import "OCTRealmManager.h"
#import "OCTCall.h"
#import "OCTLogging.h"

@interface OCTCallTimer ()

@property (strong, nonatomic) dispatch_source_t timer;
@property (strong, nonatomic) OCTRealmManager *realmManager;
@property (strong, nonatomic) OCTCall *call;

@end

@implementation OCTCallTimer

- (instancetype)initWithRealmManager:(OCTRealmManager *)realmManager
{
    self = [super init];

    if (! self) {
        return nil;
    }

    _realmManager = realmManager;

    return self;
}

- (void)startTimerForCall:(OCTCall *)call
{
    @synchronized(self) {
        if (self.timer) {
            NSAssert(! self.timer, @"There is already a timer in progress!");
        }

        self.call = call;

        // dispatch_queue_t queue = dispatch_queue_create("me.dvor.objcTox.OCTCallQueue", DISPATCH_QUEUE_SERIAL);
        // Main queue is used temporarily for now since we are getting 'Realm accessed from incorrect thread'.
        // Should really be using the queue above..

        self.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
        uint64_t interval = NSEC_PER_SEC;
        uint64_t leeway = NSEC_PER_SEC / 1000;
        dispatch_source_set_timer(self.timer, DISPATCH_TIME_NOW, interval, leeway);

        __weak OCTCallTimer *weakSelf = self;

        dispatch_source_set_event_handler(self.timer, ^{
            OCTCallTimer *strongSelf = weakSelf;
            if (! strongSelf) {
                dispatch_source_cancel(self.timer);
                OCTLogError(@"Error: Attempt to update timer with no strong pointer to OCTCallTimer");
                return;
            }

            [strongSelf.realmManager updateObject:strongSelf.call withBlock:^(OCTCall *callToUpdate) {
                callToUpdate.callDuration += 1.0;
            }];

            OCTLogInfo(@"Call: %@ duration at %f seconds", strongSelf.call, strongSelf.call.callDuration);
        });

        dispatch_resume(self.timer);
    }
}

- (void)stopTimer
{
    @synchronized(self) {
        if (! self.timer) {
            return;
        }

        OCTLogInfo(@"Timer for call %@ has stopped at duration %f", self.call, self.call.callDuration);

        dispatch_source_cancel(self.timer);
        self.timer = nil;
        self.call = nil;
    }
}

@end
