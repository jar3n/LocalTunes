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
    NSString *preferred = @"/var/mobile/Media/LocalTunes";
    BOOL exists = [fm fileExistsAtPath:preferred];
    BOOL ready = exists || [fm createDirectoryAtPath:preferred withIntermediateDirectories:YES attributes:nil error:nil];
    if (ready) {
        _musicDirectory = preferred;
        return;
    }
    NSArray *docPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *fallback = [docPaths.firstObject stringByAppendingPathComponent:@"Music"];
    [fm createDirectoryAtPath:fallback withIntermediateDirectories:YES attributes:nil error:nil];
    _musicDirectory = fallback;
}

// Cache lives next to the music folder so Filza can see it too.
- (NSString *)cachePath {
    return [self.musicDirectory stringByAppendingPathComponent:@".metadata_cache.plist"];
}

// Load the saved cache. Keys are filenames, values are dicts with
// title/artist/album/duration/moddate.
- (NSMutableDictionary *)loadCache {
    NSDictionary *saved = [NSDictionary dictionaryWithContentsOfFile:[self cachePath]];
    return saved ? [saved mutableCopy] : [NSMutableDictionary dictionary];
}

- (void)saveCache:(NSDictionary *)cache {
    [cache writeToFile:[self cachePath] atomically:YES];
}

- (void)rescan {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *contents = [fm contentsOfDirectoryAtPath:self.musicDirectory error:nil];
    NSSet *supportedExtensions = [NSSet setWithObjects:@"mp3", @"m4a", @"wav", @"aac", @"aiff", @"caf", nil];

    NSMutableDictionary *cache = [self loadCache];
    NSMutableDictionary *updatedCache = [NSMutableDictionary dictionary];
    NSMutableArray *result = [NSMutableArray array];
    BOOL cacheChanged = NO;

    for (NSString *file in contents) {
        NSString *ext = [[file pathExtension] lowercaseString];
        if (![supportedExtensions containsObject:ext]) continue;

        NSString *fullPath = [self.musicDirectory stringByAppendingPathComponent:file];

        // Use the file's modification date as a cache key so we re-read tags
        // if the file is replaced with a different version.
        NSDictionary *attrs = [fm attributesOfItemAtPath:fullPath error:nil];
        NSDate *modDate = attrs[NSFileModificationDate];
        NSString *modKey = modDate ? [NSString stringWithFormat:@"%.0f", [modDate timeIntervalSince1970]] : @"0";

        NSDictionary *cached = cache[file];
        Song *song = nil;

        if (cached && [cached[@"moddate"] isEqualToString:modKey]) {
            // Cache hit — build the Song from stored values without touching the file.
            song = [[Song alloc] initWithFilePath:fullPath];
            song.title  = cached[@"title"]  ?: song.title;
            song.artist = cached[@"artist"] ?: song.artist;
            song.album  = cached[@"album"]  ?: song.album;
            song.duration = [cached[@"duration"] doubleValue];
        } else {
            // Cache miss — read tags from the file and store them.
            song = [[Song alloc] initWithFilePath:fullPath];
            cache[file] = @{
                @"title":    song.title,
                @"artist":   song.artist,
                @"album":    song.album,
                @"duration": @(song.duration),
                @"moddate":  modKey,
            };
            cacheChanged = YES;
        }

        updatedCache[file] = cache[file];
        [result addObject:song];
    }

    // Save only if something was added/changed, and prune stale entries
    // (files that were deleted) at the same time.
    if (cacheChanged || updatedCache.count != cache.count) {
        [self saveCache:updatedCache];
    }

    [result sortUsingComparator:^NSComparisonResult(Song *a, Song *b) {
        return [a.title caseInsensitiveCompare:b.title];
    }];

    _songs = [result copy];
}

@end

