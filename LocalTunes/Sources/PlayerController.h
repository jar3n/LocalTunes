#import <Foundation/Foundation.h>
#import "Song.h"

@protocol PlayerControllerDelegate <NSObject>
@optional
- (void)playerDidChangeState;
- (void)playerDidFinishSong;
@end

@interface PlayerController : NSObject

+ (instancetype)sharedPlayer;

@property (nonatomic, weak) id<PlayerControllerDelegate> delegate;
@property (nonatomic, strong, readonly) NSArray<Song *> *queue;
@property (nonatomic, assign, readonly) NSInteger currentIndex;
@property (nonatomic, assign, readonly) BOOL isPlaying;

- (void)playQueue:(NSArray<Song *> *)songs startingAtIndex:(NSInteger)index;
- (Song *)currentSong;
- (void)togglePlayPause;
- (void)next;
- (void)previous;
- (void)seekToTime:(NSTimeInterval)time;
- (NSTimeInterval)currentTime;
- (NSTimeInterval)duration;

@end
