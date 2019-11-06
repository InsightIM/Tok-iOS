// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

//#import "DDLog.h"
//#undef LOG_LEVEL_DEF
//#define LOG_LEVEL_DEF LOG_LEVEL_VERBOSE

//#ifdef DEBUG
//@import CocoaDebug;
//#endif

//#ifdef DEBUG
//#define NSLog(fmt, ...) [_ObjcLog logWithFile:__FILE__ function:__FUNCTION__ line:__LINE__ color:[UIColor whiteColor] unicodeToChinese:NO message:(fmt), ##__VA_ARGS__]
//#else
//#define NSLog(fmt, ...) nil
//#endif

#ifdef DEBUG

#define OCTLogError(fmt, ...) //NSLog((@"[%s:Line %d] \n" fmt), [[[NSString stringWithUTF8String:__FILE__] lastPathComponent] UTF8String], __LINE__, ##__VA_ARGS__);
#define OCTLogWarn(fmt, ...) //NSLog((@"[%s:Line %d] \n" fmt), [[[NSString stringWithUTF8String:__FILE__] lastPathComponent] UTF8String], __LINE__, ##__VA_ARGS__);
#define OCTLogInfo(fmt, ...) //NSLog((@"[%s:Line %d] \n" fmt), [[[NSString stringWithUTF8String:__FILE__] lastPathComponent] UTF8String], __LINE__, ##__VA_ARGS__);
#define OCTLogDebug(fmt, ...) //NSLog((@"[%s:Line %d] \n" fmt), [[[NSString stringWithUTF8String:__FILE__] lastPathComponent] UTF8String], __LINE__, ##__VA_ARGS__);
#define OCTLogVerbose(fmt, ...) //NSLog((@"[%s:Line %d] \n" fmt), [[[NSString stringWithUTF8String:__FILE__] lastPathComponent] UTF8String], __LINE__, ##__VA_ARGS__);

#define OCTLogCError(frmt, obj, ...) //NSLog((@"<%@ %p> " frmt), [obj class], obj, ##__VA_ARGS__);
#define OCTLogCWarn(frmt, obj, ...) //NSLog((@"<%@ %p> " frmt), [obj class], obj, ##__VA_ARGS__);
#define OCTLogCInfo(frmt, obj, ...) //NSLog((@"<%@ %p> " frmt), [obj class], obj, ##__VA_ARGS__);
#define OCTLogCDebug(frmt, obj, ...) //NSLog((@"<%@ %p> " frmt), [obj class], obj, ##__VA_ARGS__);
#define OCTLogCVerbose(frmt, obj, ...) //NSLog((@"<%@ %p> " frmt), [obj class], obj, ##__VA_ARGS__);

#else

#define OCTLogError(frmt, ...)   //NSLog(@"") //DDLogError((@"<%@ %p> " frmt), [self class], self, ## __VA_ARGS__)
#define OCTLogWarn(frmt, ...)    //NSLog(@"") //DDLogWarn((@"<%@ %p> " frmt), [self class], self, ## __VA_ARGS__)
#define OCTLogInfo(frmt, ...)    //NSLog(@"") //DDLogInfo((@"<%@ %p> " frmt), [self class], self, ## __VA_ARGS__)
#define OCTLogDebug(frmt, ...)   //NSLog(@"") //DDLogDebug((@"<%@ %p> " frmt), [self class], self, ## __VA_ARGS__)
#define OCTLogVerbose(frmt, ...) //NSLog(@"") //DDLogVerbose((@"<%@ %p> " frmt), [self class], self, ## __VA_ARGS__)

#define OCTLogCError(frmt, obj, ...)   //NSLog(@"") //DDLogCError((@"<%@ %p> " frmt), [obj class], obj, ## __VA_ARGS__)
#define OCTLogCWarn(frmt, obj, ...)    //NSLog(@"") //DDLogCWarn((@"<%@ %p> " frmt), [obj class], obj, ## __VA_ARGS__)
#define OCTLogCInfo(frmt, obj, ...)    //NSLog(@"") //DDLogCInfo((@"<%@ %p> " frmt), [obj class], obj, ## __VA_ARGS__)
#define OCTLogCDebug(frmt, obj, ...)   //NSLog(@"") //DDLogCDebug((@"<%@ %p> " frmt), [obj class], obj, ## __VA_ARGS__)
#define OCTLogCVerbose(frmt, obj, ...) //NSLog(@"") //DDLogCVerbose((@"<%@ %p> " frmt), [obj class], obj, ## __VA_ARGS__)

#endif

#define OCTLogCCError(frmt, ...)   //NSLog((frmt), ## __VA_ARGS__) //DDLogCError((frmt), ## __VA_ARGS__)
#define OCTLogCCWarn(frmt, ...)    //NSLog((frmt), ## __VA_ARGS__) //DDLogCWarn((frmt), ## __VA_ARGS__)
#define OCTLogCCInfo(frmt, ...)    //NSLog((frmt), ## __VA_ARGS__) //DDLogCInfo((frmt), ## __VA_ARGS__)
#define OCTLogCCDebug(frmt, ...)   //NSLog((frmt), ## __VA_ARGS__) //DDLogCDebug((frmt), ## __VA_ARGS__)
#define OCTLogCCVerbose(frmt, ...) //NSLog((frmt), ## __VA_ARGS__) //DDLogCVerbose((frmt), ## __VA_ARGS__)
