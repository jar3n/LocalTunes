#import "NowPlayingViewController.h"
#import "PlayerController.h"
#import "Song.h"

@interface NowPlayingViewController ()
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *artistLabel;
@property (nonatomic, strong) UILabel *albumLabel;
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

    // iOS 7+: keep content below the navigation bar instead of under it
    if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }

    self.view.backgroundColor = [UIColor whiteColor];
    self.title = @"Now Playing";

    CGFloat w = self.view.bounds.size.width;
    CGFloat top = 30; // top margin from the visible area (below nav bar)

    // --- Title ---
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, top, w - 40, 30)];
    self.titleLabel.font = [UIFont boldSystemFontOfSize:22];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.titleLabel];

    // --- Artist ---
    self.artistLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, top + 36, w - 40, 22)];
    self.artistLabel.font = [UIFont systemFontOfSize:17];
    self.artistLabel.textColor = [UIColor grayColor];
    self.artistLabel.textAlignment = NSTextAlignmentCenter;
    self.artistLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.artistLabel];

    // --- Album ---
    self.albumLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, top + 60, w - 40, 18)];
    self.albumLabel.font = [UIFont systemFontOfSize:13];
    self.albumLabel.textColor = [UIColor lightGrayColor];
    self.albumLabel.textAlignment = NSTextAlignmentCenter;
    self.albumLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.albumLabel];

    // --- Progress slider ---
    CGFloat sliderY = top + 110;
    self.progressSlider = [[UISlider alloc] initWithFrame:CGRectMake(20, sliderY, w - 40, 30)];
    self.progressSlider.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.progressSlider addTarget:self action:@selector(sliderTouchDown) forControlEvents:UIControlEventTouchDown];
    [self.progressSlider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
    [self.progressSlider addTarget:self action:@selector(sliderTouchUp) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    [self.view addSubview:self.progressSlider];

    // --- Current time ---
    CGFloat timeY = sliderY + 32;
    self.currentTimeLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, timeY, 55, 18)];
    self.currentTimeLabel.font = [UIFont systemFontOfSize:12];
    self.currentTimeLabel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
    [self.view addSubview:self.currentTimeLabel];

    // --- Duration ---
    self.durationLabel = [[UILabel alloc] initWithFrame:CGRectMake(w - 75, timeY, 55, 18)];
    self.durationLabel.font = [UIFont systemFontOfSize:12];
    self.durationLabel.textAlignment = NSTextAlignmentRight;
    self.durationLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.view addSubview:self.durationLabel];

    // --- Playback controls ---
    CGFloat buttonsY = timeY + 50;
    CGFloat buttonW = 64;
    CGFloat buttonH = 44;
    CGFloat gap = 20;
    CGFloat totalW = buttonW * 3 + gap * 2;
    CGFloat startX = (w - totalW) / 2;

    // Previous
    UIButton *prevButton = [UIButton buttonWithType:UIButtonTypeSystem];
    prevButton.frame = CGRectMake(startX, buttonsY, buttonW, buttonH);
    [prevButton setTitle:@"◀◀" forState:UIControlStateNormal];
    prevButton.titleLabel.font = [UIFont systemFontOfSize:20];
    [prevButton addTarget:self action:@selector(previous) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:prevButton];

    // Play / Pause
    self.playPauseButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.playPauseButton.frame = CGRectMake(startX + buttonW + gap, buttonsY, buttonW, buttonH);
    self.playPauseButton.titleLabel.font = [UIFont systemFontOfSize:26];
    [self.playPauseButton addTarget:self action:@selector(togglePlayPause) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.playPauseButton];

    // Next
    UIButton *nextButton = [UIButton buttonWithType:UIButtonTypeSystem];
    nextButton.frame = CGRectMake(startX + (buttonW + gap) * 2, buttonsY, buttonW, buttonH);
    [nextButton setTitle:@"▶▶" forState:UIControlStateNormal];
    nextButton.titleLabel.font = [UIFont systemFontOfSize:20];
    [nextButton addTarget:self action:@selector(next) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:nextButton];

    [self refreshUI];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                        target:self
                                                      selector:@selector(refreshUI)
                                                      userInfo:nil
                                                       repeats:YES];
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
    self.albumLabel.text = song.album;

    NSTimeInterval duration = [player duration];
    NSTimeInterval current = [player currentTime];

    if (!self.isScrubbing && duration > 0) {
        self.progressSlider.value = current / duration;
    }

    self.currentTimeLabel.text = [self formatTime:current];
    self.durationLabel.text = [self formatTime:duration];

    [self.playPauseButton setTitle:player.isPlaying ? @"■" : @"▶" forState:UIControlStateNormal];
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
