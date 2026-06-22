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

    NSArray *keys = @[ @"commonMetadata" ];

    NSError *error = nil;
    [asset loadValuesAsynchronouslyForKeys:keys completionHandler:^{
        AVKeyValueStatus status = [asset statusOfValueForKey:@"commonMetadata" error:&error];
        if (status != AVKeyValueStatusLoaded) { return; }

        NSArray *items = asset.commonMetadata;

        NSString *author = nil;
        NSString *title = nil;

        for (AVMetadataItem *item in items) {
            if (![item commonKey]) continue;

            NSString *value = nil;
            // common keys often come with item.value as an object you can stringify
            if ([item.value isKindOfClass:[NSString class]]) value = (NSString *)item.value;
            else if ([item.value respondsToSelector:@selector(stringValue)]) value = [item.value stringValue];

            if (!value) continue;

            if ([item.commonKey isEqualToString:@"artist"]) author = value;
            if ([item.commonKey isEqualToString:@"title"])  title  = value;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            // use author and title here
            // self.author = author;
            // self.songTitle = title;
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
