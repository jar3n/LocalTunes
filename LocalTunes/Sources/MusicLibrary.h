#import <Foundation/Foundation.h>
#import "Song.h"

@interface MusicLibrary : NSObject

+ (instancetype)sharedLibrary;

// The folder you should point Filza at to copy music files in.
@property (nonatomic, readonly, copy) NSString *musicDirectory;
@property (nonatomic, readonly, strong) NSArray<Song *> *songs;

- (void)rescan;

@end
