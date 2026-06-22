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

    // Force a synchronous load of commonMetadata and duration before reading
    // them. Without this, AVAsset on older iOS returns empty arrays and zero
    // duration because the asset hasn't finished inspecting the file yet.
    NSError *error = nil;
    [asset loadValuesAndReturnError:&error];

    self.duration = CMTimeGetSeconds(asset.duration);

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
