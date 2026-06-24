#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@class OGGPlayer;

@protocol OGGPlayerDelegate <NSObject>
- (void)oggPlayerDidFinishPlaying:(OGGPlayer *)player;
@end

@interface OGGPlayer : NSObject

- (instancetype)initWithContentsOfFile:(NSString *)path error:(NSError **)error;

- (BOOL)play;
- (void)pause;
- (void)stop;
- (void)seekToTime:(NSTimeInterval)time;

@property (nonatomic, weak) id<OGGPlayerDelegate> delegate;
@property (nonatomic, readonly, getter=isPlaying) BOOL playing;
@property (nonatomic, readonly) NSTimeInterval duration;
@property (nonatomic, readonly) NSTimeInterval currentTime;

@end
