#import "PlayerController.h"
#import "OGGPlayer.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>

@interface PlayerController () <AVAudioPlayerDelegate, OGGPlayerDelegate>
@property (nonatomic, strong) AVAudioPlayer *audioPlayer;
@property (nonatomic, strong) OGGPlayer *oggPlayer;
@property (nonatomic, strong) NSArray<Song *> *queue;
@property (nonatomic, assign) NSInteger currentIndex;
@property (nonatomic, assign) BOOL isOGG;
@end

@implementation PlayerController

+ (instancetype)sharedPlayer {
    static PlayerController *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[PlayerController alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _queue = @[];
        _currentIndex = -1;
        [self setupRemoteCommandCenter];
    }
    return self;
}

- (void)setupRemoteCommandCenter {
    // MPRemoteCommandCenter is iOS 7.1+; guard so this still builds/runs fine
    // on iOS 6 devices, just without lock-screen button support there.
    Class commandCenterClass = NSClassFromString(@"MPRemoteCommandCenter");
    if (!commandCenterClass) return;

    MPRemoteCommandCenter *center = [MPRemoteCommandCenter sharedCommandCenter];

    __weak typeof(self) weakSelf = self;

    [center.playCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
        if (!weakSelf.isPlaying) [weakSelf togglePlayPause];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    [center.pauseCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
        if (weakSelf.isPlaying) [weakSelf togglePlayPause];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    [center.nextTrackCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
        [weakSelf next];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    [center.previousTrackCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
        [weakSelf previous];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
}

- (void)playQueue:(NSArray<Song *> *)songs startingAtIndex:(NSInteger)index {
    self.queue = songs;
    self.currentIndex = index;
    [self playCurrent];
}

- (void)stopCurrent {
    if (self.isOGG) {
        [self.oggPlayer stop];
        self.oggPlayer = nil;
    } else {
        [self.audioPlayer stop];
        self.audioPlayer = nil;
    }
}

- (void)playCurrent {
    Song *song = [self currentSong];
    if (!song) return;

    // Stop whatever is currently playing
    [self stopCurrent];

    // Check if this is an OGG file
    NSString *ext = [[song.filePath pathExtension] lowercaseString];
    self.isOGG = [ext isEqualToString:@"ogg"];

    if (self.isOGG) {
        NSError *error = nil;
        self.oggPlayer = [[OGGPlayer alloc] initWithContentsOfFile:song.filePath error:&error];
        self.oggPlayer.delegate = self;
        [self.oggPlayer play];
    } else {
        NSError *error = nil;
        NSURL *url = [NSURL fileURLWithPath:song.filePath];
        self.audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error];
        self.audioPlayer.delegate = self;
        [self.audioPlayer prepareToPlay];
        [self.audioPlayer play];
    }

    [self updateNowPlayingInfo];
    [self notifyStateChanged];
}

- (Song *)currentSong {
    if (self.currentIndex < 0 || self.currentIndex >= (NSInteger)self.queue.count) return nil;
    return self.queue[self.currentIndex];
}

- (BOOL)isPlaying {
    if (self.isOGG) {
        return self.oggPlayer.isPlaying;
    }
    return self.audioPlayer.isPlaying;
}

- (void)togglePlayPause {
    if (self.isOGG) {
        if (!self.oggPlayer) return;
        if (self.oggPlayer.isPlaying) {
            [self.oggPlayer pause];
        } else {
            [self.oggPlayer play];
        }
    } else {
        if (!self.audioPlayer) return;
        if (self.audioPlayer.isPlaying) {
            [self.audioPlayer pause];
        } else {
            [self.audioPlayer play];
        }
    }

    [self updateNowPlayingInfo];
    [self notifyStateChanged];
}

- (void)next {
    if (self.queue.count == 0) return;
    self.currentIndex = (self.currentIndex + 1) % (NSInteger)self.queue.count;
    [self playCurrent];
}

- (void)previous {
    if (self.queue.count == 0) return;
    self.currentIndex = (self.currentIndex - 1 + (NSInteger)self.queue.count) % (NSInteger)self.queue.count;
    [self playCurrent];
}

- (void)seekToTime:(NSTimeInterval)time {
    if (self.isOGG) {
        [self.oggPlayer seekToTime:time];
    } else {
        self.audioPlayer.currentTime = time;
    }
    [self updateNowPlayingInfo];
}

- (NSTimeInterval)currentTime {
    if (self.isOGG) {
        return self.oggPlayer.currentTime;
    }
    return self.audioPlayer.currentTime;
}

- (NSTimeInterval)duration {
    if (self.isOGG) {
        return self.oggPlayer.duration;
    }
    return self.audioPlayer.duration;
}

- (void)updateNowPlayingInfo {
    Song *song = [self currentSong];
    if (!song) return;

    Class infoCenterClass = NSClassFromString(@"MPNowPlayingInfoCenter");
    if (!infoCenterClass) return;

    NSTimeInterval dur = [self duration];
    NSTimeInterval cur = [self currentTime];
    BOOL playing = [self isPlaying];

    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[MPMediaItemPropertyTitle] = song.title;
    info[MPMediaItemPropertyArtist] = song.artist;
    info[MPMediaItemPropertyAlbumTitle] = song.album;
    info[MPMediaItemPropertyPlaybackDuration] = @(dur);
    info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = @(cur);
    info[MPNowPlayingInfoPropertyPlaybackRate] = @(playing ? 1.0 : 0.0);

    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = info;
}

- (void)notifyStateChanged {
    if ([self.delegate respondsToSelector:@selector(playerDidChangeState)]) {
        [self.delegate playerDidChangeState];
    }
}

#pragma mark - AVAudioPlayerDelegate

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    [self songFinished];
}

#pragma mark - OGGPlayerDelegate

- (void)oggPlayerDidFinishPlaying:(OGGPlayer *)player {
    [self songFinished];
}

- (void)songFinished {
    if ([self.delegate respondsToSelector:@selector(playerDidFinishSong)]) {
        [self.delegate playerDidFinishSong];
    }
    [self next];
}

@end
