#import "Song.h"
#import <AVFoundation/AVFoundation.h>

@implementation Song

- (instancetype)initWithFilePath:(NSString *)path {
    self = [super init];
    if (self) {
        _filePath = [path copy];
        _title = [[path lastPathComponent] stringByDeletingPathExtension];
        _artist = @"Unknown Artist";
        _album = @"Unknown Album";
        _duration = 0;

        [self loadMetadata];
    }
    return self;
}

- (void)loadMetadata {
    NSURL *url = [NSURL fileURLWithPath:self.filePath];
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];

    NSError *error = nil;
    
    NSArray *keys = @[ @"duration", @"tracks" ]; // add the keys you actually use

    [asset loadValuesAsynchronouslyForKeys:keys completionHandler:^{
        for (NSString *key in keys) {
            NSError *keyError = nil;
            AVKeyValueStatus status = [asset statusOfValueForKey:key error:&keyError];

            if (status == AVKeyValueStatusLoaded) {
                continue;
            } else {
                // handle error (keyError) on the place you need results
                dispatch_async(dispatch_get_main_queue(), ^{
                    // your failure handling
                });
                return;
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            // now it’s safe to read asset.duration / asset.tracks, etc.
        });
    }];

    self.duration = CMTimeGetSeconds(asset.duration);

    // AVAsset reads embedded ID3/iTunes-style tags directly from the file,
    // so this works without ever importing into the iOS Music library.
    for (AVMetadataItem *item in asset.commonMetadata) {
        if ([item.commonKey isEqualToString:AVMetadataCommonKeyTitle] && item.stringValue.length > 0) {
            self.title = item.stringValue;
        } else if ([item.commonKey isEqualToString:AVMetadataCommonKeyArtist] && item.stringValue.length > 0) {
            self.artist = item.stringValue;
        } else if ([item.commonKey isEqualToString:AVMetadataCommonKeyAlbumName] && item.stringValue.length > 0) {
            self.album = item.stringValue;
        }
    }
}

@end
