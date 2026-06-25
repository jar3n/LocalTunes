#import "Song.h"
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIImage.h>
#import <vorbis/vorbisfile.h>

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
    NSString *ext = [[self.filePath pathExtension] lowercaseString];
    if ([ext isEqualToString:@"ogg"]) {
        [self loadOGGMetadata];
    } else {
        [self loadAVMetadata];
    }
}

- (void)loadAVMetadata {
    NSURL *url = [NSURL fileURLWithPath:self.filePath];
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];

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
        } else if ([item.commonKey isEqualToString:AVMetadataCommonKeyArtwork]) {
            // Artwork can be NSData (ID3) or a dictionary (iTunes-style)
            if ([item.value isKindOfClass:[NSData class]]) {
                self.artwork = [UIImage imageWithData:(NSData *)item.value];
            } else if ([item.value isKindOfClass:[NSDictionary class]]) {
                NSDictionary *dict = (NSDictionary *)item.value;
                NSData *data = dict[@"data"];
                if (data) {
                    self.artwork = [UIImage imageWithData:data];
                }
            }
        }
    }
}

- (void)loadOGGMetadata {
    FILE *fp = fopen([self.filePath UTF8String], "rb");
    if (!fp) return;

    OggVorbis_File vf;
    if (ov_open(fp, &vf, NULL, 0) < 0) {
        fclose(fp);
        return;
    }

    // Duration
    double total = ov_time_total(&vf, -1);
    if (total >= 0) {
        self.duration = total;
    }

    // Vorbis comments (metadata)
    vorbis_comment *vc = ov_comment(&vf, -1);
    if (vc) {
        for (int i = 0; i < vc->comments; i++) {
            NSString *comment = [NSString stringWithUTF8String:vc->user_comments[i]];
            if (comment.length == 0) continue;

            NSRange eq = [comment rangeOfString:@"="];
            if (eq.location == NSNotFound || eq.location == 0) continue;

            NSString *key = [[comment substringToIndex:eq.location] uppercaseString];
            NSString *value = [comment substringFromIndex:eq.location + 1];
            if (value.length == 0) continue;

            if ([key isEqualToString:@"TITLE"]) {
                self.title = value;
            } else if ([key isEqualToString:@"ARTIST"]) {
                self.artist = value;
            } else if ([key isEqualToString:@"ALBUM"]) {
                self.album = value;
            }
        }
    }

    ov_clear(&vf);
}

@end
