#import "RootViewController.h"
#import "MusicLibrary.h"
#import "PlayerController.h"
#import "NowPlayingViewController.h"

@interface RootViewController () <PlayerControllerDelegate>
@property (nonatomic, strong) UIView *miniPlayerView;
@property (nonatomic, strong) UILabel *miniPlayerLabel;
@property (nonatomic, strong) UIButton *miniPlayerPlayPauseButton;
@end

@implementation RootViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Local Music";
    self.tableView.rowHeight = 56;

    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                        target:self
                                                        action:@selector(rescan)];

    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"Folder"
                                          style:UIBarButtonItemStylePlain
                                         target:self
                                         action:@selector(showFolderPath)];

    [PlayerController sharedPlayer].delegate = self;

    [self setupMiniPlayer];
    [self updateMiniPlayer];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
    [self updateMiniPlayer];
}

- (void)rescan {
    [[MusicLibrary sharedLibrary] rescan];
    [self.tableView reloadData];

    if ([MusicLibrary sharedLibrary].songs.count == 0) {
        [self showFolderPath];
    }
}

- (void)showFolderPath {
    NSString *path = [MusicLibrary sharedLibrary].musicDirectory;
    UIAlertView *alert = [[UIAlertView alloc]
        initWithTitle:@"Music Folder"
              message:[NSString stringWithFormat:@"Use Filza to copy mp3/m4a files into:\n\n%@\n\nThen tap the refresh button.", path]
             delegate:nil
    cancelButtonTitle:@"OK"
    otherButtonTitles:nil];
    [alert show];
}

#pragma mark - Mini Player

- (void)setupMiniPlayer {
    CGFloat height = 50;
    CGRect frame = self.view.bounds;

    self.miniPlayerView = [[UIView alloc] initWithFrame:CGRectMake(0, frame.size.height - height, frame.size.width, height)];
    self.miniPlayerView.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0];
    self.miniPlayerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;

    UIView *topBorder = [[UIView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, 0.5)];
    topBorder.backgroundColor = [UIColor colorWithWhite:0.8 alpha:1.0];
    topBorder.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.miniPlayerView addSubview:topBorder];

    self.miniPlayerLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 0, frame.size.width - 80, height)];
    self.miniPlayerLabel.font = [UIFont systemFontOfSize:14];
    self.miniPlayerLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.miniPlayerView addSubview:self.miniPlayerLabel];

    self.miniPlayerPlayPauseButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.miniPlayerPlayPauseButton.frame = CGRectMake(frame.size.width - 70, 5, 60, 40);
    self.miniPlayerPlayPauseButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.miniPlayerPlayPauseButton setTitle:@"Play" forState:UIControlStateNormal];
    [self.miniPlayerPlayPauseButton addTarget:self action:@selector(togglePlayPause) forControlEvents:UIControlEventTouchUpInside];
    [self.miniPlayerView addSubview:self.miniPlayerPlayPauseButton];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(openNowPlaying)];
    [self.miniPlayerLabel addGestureRecognizer:tap];
    self.miniPlayerLabel.userInteractionEnabled = YES;

    [self.view addSubview:self.miniPlayerView];
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, height, 0);
}

- (void)updateMiniPlayer {
    Song *song = [[PlayerController sharedPlayer] currentSong];
    if (song) {
        self.miniPlayerLabel.text = [NSString stringWithFormat:@"%@ — %@", song.title, song.artist];
    } else {
        self.miniPlayerLabel.text = @"No song playing";
    }
    NSString *title = [PlayerController sharedPlayer].isPlaying ? @"Pause" : @"Play";
    [self.miniPlayerPlayPauseButton setTitle:title forState:UIControlStateNormal];
}

- (void)togglePlayPause {
    [[PlayerController sharedPlayer] togglePlayPause];
    [self updateMiniPlayer];
}

- (void)openNowPlaying {
    if (![[PlayerController sharedPlayer] currentSong]) return;
    NowPlayingViewController *vc = [[NowPlayingViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark - PlayerControllerDelegate

- (void)playerDidChangeState {
    [self updateMiniPlayer];
}

- (void)playerDidFinishSong {
    [self updateMiniPlayer];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [MusicLibrary sharedLibrary].songs.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"SongCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
    }
    Song *song = [MusicLibrary sharedLibrary].songs[indexPath.row];
    cell.textLabel.text = song.title;
    cell.detailTextLabel.text = song.artist;
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSArray *songs = [MusicLibrary sharedLibrary].songs;
    [[PlayerController sharedPlayer] playQueue:songs startingAtIndex:indexPath.row];
    [self updateMiniPlayer];
}

@end
