//
//  OCTRange.h
//  Tok
//
//  Created by Bryce on 2019/8/20.
//  Copyright © 2019 Insight. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OCTObject.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCTRange : OCTObject

@property NSString *chatUniqueIdentifier;

@property NSTimeInterval startTimeInterval;

@property NSTimeInterval endTimeInterval;

@property long long startMessageId;

@property long long endMessageId;

@end

NS_ASSUME_NONNULL_END
