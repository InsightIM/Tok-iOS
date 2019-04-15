
#ifndef FCOggOpusError_h
#define FCOggOpusError_h

#import <Foundation/Foundation.h>

FOUNDATION_EXTERN const NSErrorDomain FCOggOpusErrorDomain;

typedef NS_ENUM(NSUInteger, FCOggOpusErrorCode) {
    FCOggOpusErrorCodeCreateEncoder,
    FCOggOpusErrorCodeSetBitrate,
    FCOggOpusErrorCodeEncodingFailed,
    FCOggOpusErrorCodeOpenFile,
    FCOggOpusErrorCodeRead
};

NS_INLINE NSError* ErrorWithCodeAndOpusErrorCode(FCOggOpusErrorCode code, int32_t opusCode) {
    return [NSError errorWithDomain:FCOggOpusErrorDomain
                               code:code
                           userInfo:@{@"opus_code" : @(opusCode)}];
}

#endif /* FCOggOpusError_h */
