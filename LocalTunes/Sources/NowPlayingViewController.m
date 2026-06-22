#import "NowPlayingViewController.h"
#import "PlayerController.h"
#import "Song.h"

@interface NowPlayingViewController ()
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *artistLabel;
@property (nonatomic, strong) UISlider *progressSlider;
@property (nonatomic, strong) UILabel *currentTimeLabel;
@property (nonatomic, strong) UILabel *durationLabel;
@property (nonatomic, strong) UIButton *playPauseButton;
@property (nonatomic, strong) NSTimer *updateTimer;
@property (nonatomic, assign) BOOL isScrubbing;
@end

@implementation NowPlayingViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    self.title = @"Now Playing";

    CGFloat w = self.view.bounds.size.width;

    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 40, w - 40, 30)];
    self.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.titleLabel];

    self.artistLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 75, w - 40, 24)];
    self.artistLabel.font = [UIFont systemFontOfSize:16];
    self.artistLabel.textColor = [UIColor grayColor];
    self.artistLabel.textAlignment = NSTextAlignmentCenter;
    self.artistLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.artistLabel];

    self.progressSlider = [[UISlider alloc] initWithFrame:CGRectMake(20, 140, w - 40, 30)];
    self.progressSlider.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.progressSlider addTarget:self action:@selector(sliderTouchDown) forControlEvents:UIControlEventTouchDown];
    [self.progressSlider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
    [self.progressSlider addTarget:self action:@selector(sliderTouchUp) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    [self.view addSubview:self.progressSlider];

    self.currentTimeLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 170, 60, 20)];
    self.currentTimeLabel.font = [UIFont systemFontOfSize:12];
    [self.view addSubview:self.currentTimeLabel];

    self.durationLabel = [[UILabel alloc] initWithFrame:CGRectMake(w - 80, 170, 60, 20)];
    self.durationLabel.font = [UIFont systemFontOfSize:12];
    self.durationLabel.textAlignment = NSTextAlignmentRight;
    self.durationLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.view addSubview:self.durationLabel];

    UIButton *prevButton = [UIButton buttonWithType:UIButtonTypeSystem];
    prevButton.frame = CGRectMake(w/2 - 100, 220, 60, 44);
    [prevButton setTitle:@"Prev" forState:UIControlStateNormal];
    [prevButton addTarget:self action:@selector(previous) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:prevButton];

    self.playPauseButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.playPauseButton.frame = CGRectMake(w/2 - 30, 220, 60, 44);
    [self.playPauseButton addTarget:self action:@selector(togglePlayPause) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.playPauseButton];

    UIButton *nextButton = [UIButton buttonWithType:UIButtonTypeSystem];
    nextButton.frame = CGRectMake(w/2 + 40, 220, 60, 44);
    [nextButton setTitle:@"Next" forState:UIControlStateNormal];
    [nextButton addTarget:self action:@selector(next) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:nextButton];

    [self refreshUI];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(refreshUI) userInfo:nil repeats:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.updateTimer invalidate];
    self.updateTimer = nil;
}

- (void)refreshUI {
    PlayerController *player = [PlayerController sharedPlayer];
    Song *song = [player currentSong];
    if (!song) return;

    self.titleLabel.text = song.title;
    self.artistLabel.text = song.artist;

    NSTimeInterval duration = [player duration];
    NSTimeInterval current = [player currentTime];

    if (!self.isScrubbing && duration > 0) {
        self.progressSlider.value = current / duration;
    }

    self.currentTimeLabel.text = [self formatTime:current];
    self.durationLabel.text = [self formatTime:duration];

    [self.playPauseButton setTitle:player.isPlaying ? @"Pause" : @"Play" forState:UIControlStateNormal];
}

- (NSString *)formatTime:(NSTimeInterval)time {
    if (isnan(time) || time < 0) time = 0;
    NSInteger minutes = (NSInteger)time / 60;
    NSInteger seconds = (NSInteger)time % 60;
    return [NSString stringWithFormat:@"%ld:%02ld", (long)minutes, (long)seconds];
}

- (void)sliderTouchDown {
    self.isScrubbing = YES;
}

- (void)sliderChanged:(UISlider *)slider {
    PlayerController *player = [PlayerController sharedPlayer];
    NSTimeInterval newTime = slider.value * [player duration];
    self.currentTimeLabel.text = [self formatTime:newTime];
}

- (void)sliderTouchUp {
    PlayerController *player = [PlayerController sharedPlayer];
    NSTimeInterval newTime = self.progressSlider.value * [player duration];
    [player seekToTime:newTime];
    self.isScrubbing = NO;
}

- (void)togglePlayPause {
    [[PlayerController sharedPlayer] togglePlayPause];
    [self refreshUI];
}

- (void)next {
    [[PlayerController sharedPlayer] next];
    [self refreshUI];
}

- (void)previous {
    [[PlayerController sharedPlayer] previous];
    [self refreshUI];
}

@end
