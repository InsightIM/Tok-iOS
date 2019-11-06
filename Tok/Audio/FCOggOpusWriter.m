
#import "FCOggOpusWriter.h"
#import "FCOggOpusError.h"
#import "opus.h"
#import "ogg.h"
#import "opus_multistream.h"
#import "opusenc.h"

static const int numberOfChannels = 1;
static const int outputBitRate = 16 * 1024;

@implementation FCOggOpusWriter {
    NSString *_path;
    OggOpusEnc *_encoder;
    OggOpusComments *_comments;
}

+ (instancetype)writerWithPath:(NSString *)path
               inputSampleRate:(int32_t)inputSampleRate
                         error:(NSError * _Nullable *)outError {
    return [[FCOggOpusWriter alloc] initWithPath:path
                                  inputSampleRate:inputSampleRate
                                            error:outError];
}

- (nullable instancetype)initWithPath:(NSString *)path
                      inputSampleRate:(int32_t)inputSampleRate
                                error:(NSError * _Nullable *)outError {
    self = [super init];
    if (self) {
        _comments = ope_comments_create();
        int result = OPE_OK;
        _encoder = ope_encoder_create_file([path UTF8String], _comments, inputSampleRate, numberOfChannels, 0, &result);
        if (result != OPE_OK) {
            if (outError) {
                *outError = [NSError errorWithDomain:FCOggOpusErrorDomain
                                                code:FCOggOpusErrorCodeCreateEncoder
                                            userInfo:@{@"ope_code" : @(result)}];
            }
            return nil;
        }
        result = ope_encoder_ctl(_encoder, OPUS_SET_BITRATE_REQUEST, outputBitRate);
        if (result != OPE_OK) {
            if (outError) {
                *outError = [NSError errorWithDomain:FCOggOpusErrorDomain
                                                code:FCOggOpusErrorCodeSetBitrate
                                            userInfo:@{@"ope_code" : @(result)}];
            }
            return nil;
        }
    }
    return self;
}

- (void)close {
    ope_encoder_drain(_encoder);
    ope_encoder_destroy(_encoder);
    ope_comments_destroy(_comments);
}

- (void)removeFile {
    [[NSFileManager defaultManager] removeItemAtPath:_path error:nil];
}

- (void)writePCMData:(NSData *)pcmData {
    ope_encoder_write(_encoder, pcmData.bytes, (int)pcmData.length / 2);
}

@end
