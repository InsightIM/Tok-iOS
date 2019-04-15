
#import "FCAudioMetadata.h"

@implementation FCAudioMetadata

+ (instancetype)metadataWithDuration:(NSUInteger)duration waveform:(NSData *)waveform {
    return [[FCAudioMetadata alloc] initWithDuration:duration waveform:waveform];
}

- (instancetype)initWithDuration:(NSUInteger)duration waveform:(NSData *)waveform {
    self = [super init];
    if (self) {
        _duration = duration;
        _waveform = waveform;
    }
    return self;
}

@end
