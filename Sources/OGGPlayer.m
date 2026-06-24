#import "OGGPlayer.h"
#import <vorbis/vorbisfile.h>

#define NUM_BUFFERS 3
#define BUFFER_SIZE 88200  // ~0.5s at 44100Hz stereo 16-bit

@interface OGGPlayer () {
    OggVorbis_File _vf;
    AudioQueueRef _audioQueue;
    AudioQueueBufferRef _buffers[NUM_BUFFERS];
    AudioStreamBasicDescription _format;
    BOOL _playing;
    BOOL _reachedEOF;
    NSTimeInterval _duration;
    BOOL _fileOpen;
}
- (void)fillBuffer:(AudioQueueBufferRef)buffer;
- (BOOL)isAtEOF;
- (void)handlePlaybackFinished;
@end

// C callback for AudioQueue
static void audioQueueCallback(void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer) {
    OGGPlayer *player = (__bridge OGGPlayer *)inUserData;
    [player fillBuffer:inBuffer];
}

// C callback for AudioQueue is-running property
static void audioQueueRunningListener(void *inUserData, AudioQueueRef inAQ, AudioQueuePropertyID inID) {
    OGGPlayer *player = (__bridge OGGPlayer *)inUserData;
    UInt32 isRunning;
    UInt32 size = sizeof(isRunning);
    AudioQueueGetProperty(inAQ, kAudioQueueProperty_IsRunning, &isRunning, &size);
    if (!isRunning && [player isAtEOF]) {
        [player handlePlaybackFinished];
    }
}

@implementation OGGPlayer

- (instancetype)initWithContentsOfFile:(NSString *)path error:(NSError **)error {
    self = [super init];
    if (!self) return nil;

    _fileOpen = NO;

    FILE *fp = fopen([path UTF8String], "rb");
    if (!fp) {
        if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                                code:NSFileReadUnknownError
                                            userInfo:@{NSLocalizedDescriptionKey: @"Could not open file"}];
        return self;
    }

    if (ov_open(fp, &_vf, NULL, 0) < 0) {
        fclose(fp);
        if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                                code:NSFileReadUnknownError
                                            userInfo:@{NSLocalizedDescriptionKey: @"Not a valid OGG Vorbis file"}];
        return self;
    }
    _fileOpen = YES;

    vorbis_info *vi = ov_info(&_vf, -1);
    if (!vi) {
        [self cleanup];
        if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                                code:NSFileReadUnknownError
                                            userInfo:@{NSLocalizedDescriptionKey: @"Could not read OGG info"}];
        return self;
    }

    _duration = ov_time_total(&_vf, -1);
    if (_duration < 0) _duration = 0;

    _format.mSampleRate = vi->rate;
    _format.mFormatID = kAudioFormatLinearPCM;
    _format.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    _format.mBytesPerPacket = vi->channels * 2;
    _format.mFramesPerPacket = 1;
    _format.mBytesPerFrame = vi->channels * 2;
    _format.mChannelsPerFrame = vi->channels;
    _format.mBitsPerChannel = 16;
    _format.mReserved = 0;

    OSStatus status = AudioQueueNewOutput(&_format, audioQueueCallback,
                                          (__bridge void *)self, NULL,
                                          kCFRunLoopCommonModes, 0, &_audioQueue);
    if (status != noErr) {
        [self cleanup];
        if (error) *error = [NSError errorWithDomain:NSOSStatusErrorDomain
                                                code:status
                                            userInfo:@{NSLocalizedDescriptionKey: @"Could not create audio queue"}];
        return self;
    }

    AudioQueueAddPropertyListener(_audioQueue, kAudioQueueProperty_IsRunning,
                                  audioQueueRunningListener, (__bridge void *)self);

    for (int i = 0; i < NUM_BUFFERS; i++) {
        AudioQueueAllocateBuffer(_audioQueue, BUFFER_SIZE, &_buffers[i]);
        [self fillBuffer:_buffers[i]];
    }

    return self;
}

- (void)fillBuffer:(AudioQueueBufferRef)buffer {
    if (!_fileOpen) return;

    int totalBytes = 0;
    buffer->mAudioDataByteSize = 0;

    while (totalBytes < BUFFER_SIZE) {
        int section;
        long result = ov_read(&_vf,
                              (char *)buffer->mAudioData + totalBytes,
                              BUFFER_SIZE - totalBytes,
                              0,  // little endian
                              2,  // 16-bit samples
                              1,  // signed
                              &section);
        if (result > 0) {
            totalBytes += result;
        } else {
            break;
        }
    }

    buffer->mAudioDataByteSize = totalBytes;

    if (totalBytes > 0) {
        AudioQueueEnqueueBuffer(_audioQueue, buffer, 0, NULL);
    } else {
        _reachedEOF = YES;
    }
}

- (BOOL)isAtEOF {
    return _reachedEOF;
}

- (BOOL)play {
    if (!_fileOpen) return NO;
    _playing = YES;
    OSStatus status = AudioQueueStart(_audioQueue, NULL);
    return status == noErr;
}

- (void)pause {
    if (!_fileOpen) return;
    _playing = NO;
    AudioQueuePause(_audioQueue);
}

- (void)stop {
    if (!_fileOpen) return;
    _playing = NO;
    AudioQueueStop(_audioQueue, YES);
    ov_raw_seek(&_vf, 0);
}

- (void)seekToTime:(NSTimeInterval)time {
    if (!_fileOpen) return;

    BOOL wasPlaying = _playing;
    AudioQueueStop(_audioQueue, YES);
    ov_time_seek(&_vf, time);

    for (int i = 0; i < NUM_BUFFERS; i++) {
        AudioQueueFreeBuffer(_audioQueue, _buffers[i]);
        AudioQueueAllocateBuffer(_audioQueue, BUFFER_SIZE, &_buffers[i]);
        [self fillBuffer:_buffers[i]];
    }

    if (wasPlaying) {
        _playing = YES;
        AudioQueueStart(_audioQueue, NULL);
    }
}

- (BOOL)isPlaying {
    return _playing;
}

- (NSTimeInterval)duration {
    return _duration;
}

- (NSTimeInterval)currentTime {
    if (!_fileOpen) return 0;
    return ov_time_tell(&_vf);
}

- (void)cleanup {
    if (_audioQueue) {
        AudioQueueStop(_audioQueue, YES);
        AudioQueueDispose(_audioQueue, YES);
        _audioQueue = NULL;
    }
    if (_fileOpen) {
        ov_clear(&_vf);
        _fileOpen = NO;
    }
}

- (void)handlePlaybackFinished {
    _playing = NO;
    if ([self.delegate respondsToSelector:@selector(oggPlayerDidFinishPlaying:)]) {
        [self.delegate oggPlayerDidFinishPlaying:self];
    }
}

- (void)dealloc {
    [self cleanup];
}

@end
