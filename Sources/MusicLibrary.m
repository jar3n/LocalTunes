#import "MusicLibrary.h"

@implementation MusicLibrary

+ (instancetype)sharedLibrary {
    static MusicLibrary *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[MusicLibrary alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self resolveMusicDirectory];
        _songs = @[];
        [self rescan];
    }
    return self;
}

- (void)resolveMusicDirectory {
    NSFileManager *fm = [NSFileManager defaultManager];

    // Preferred: a fixed path under the shared Media partition. This is the
    // same convention Filza, Photos, etc. use, so it's easy for you to find
    // and drop files into without digging through a sandboxed container UUID.
    NSString *preferred = @"/var/mobile/Media/LocalTunes";

    BOOL exists = [fm fileExistsAtPath:preferred];
    BOOL ready = exists || [fm createDirectoryAtPath:preferred withIntermediateDirectories:YES attributes:nil error:nil];

    if (ready) {
        _musicDirectory = preferred;
        return;
    }

    // Fallback if the sandbox on your jailbreak doesn't allow writing to
    // /var/mobile/Media directly: the app's own sandboxed Documents/Music
    // folder. You can still reach this with Filza under
    // /var/mobile/Containers/Data/Application/<this app's UUID>/Documents/Music
    NSArray *docPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *fallback = [docPaths.firstObject stringByAppendingPathComponent:@"Music"];
    [fm createDirectoryAtPath:fallback withIntermediateDirectories:YES attributes:nil error:nil];
    _musicDirectory = fallback;
}

- (void)rescan {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *contents = [fm contentsOfDirectoryAtPath:self.musicDirectory error:nil];

    NSSet *supportedExtensions = [NSSet setWithObjects:@"mp3", @"m4a", @"wav", @"aac", @"aiff", @"caf", @"ogg", nil];

    NSMutableArray *result = [NSMutableArray array];
    for (NSString *file in contents) {
        NSString *ext = [[file pathExtension] lowercaseString];
        if ([supportedExtensions containsObject:ext]) {
            NSString *fullPath = [self.musicDirectory stringByAppendingPathComponent:file];
            Song *song = [[Song alloc] initWithFilePath:fullPath];
            [result addObject:song];
        }
    }

    [result sortUsingComparator:^NSComparisonResult(Song *a, Song *b) {
        return [a.title caseInsensitiveCompare:b.title];
    }];

    _songs = [result copy];
}

@end
