#import "RootViewController.h"
#import "MusicLibrary.h"
#import "PlayerController.h"
#import "NowPlayingViewController.h"

@interface RootViewController () <PlayerControllerDelegate, UISearchBarDelegate, UIScrollViewDelegate>
@property (nonatomic, strong) UIView *miniPlayerView;
@property (nonatomic, strong) UILabel *miniPlayerLabel;
@property (nonatomic, strong) UIButton *miniPlayerPlayPauseButton;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) NSArray<Song *> *allSongs;
@property (nonatomic, strong) NSArray<Song *> *filteredSongs;
@property (nonatomic, assign) BOOL searchBarActive;
@end

@implementation RootViewController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Local Music";
    self.tableView.rowHeight = 56;

    // Dark theme
    self.tableView.backgroundColor = [UIColor blackColor];
    self.tableView.separatorColor = [UIColor colorWithRed:0.35 green:0.96 blue:0.31 alpha:0.3];

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

    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"Search songs or artists";
    self.searchBar.barStyle = UIBarStyleBlack;
    self.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    self.searchBar.tintColor = [UIColor colorWithRed:0.35 green:0.96 blue:0.31 alpha:1.0];

    // Wrap in a container so iOS doesn't reposition the search bar when active
    UIView *headerContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    headerContainer.backgroundColor = [UIColor clearColor];
    headerContainer.clipsToBounds = YES;
    self.searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.searchBar.frame = headerContainer.bounds;
    [headerContainer addSubview:self.searchBar];
    self.tableView.tableHeaderView = headerContainer;

    // iOS 7+ search bar appearance
    if ([self.searchBar respondsToSelector:@selector(setBarTintColor:)]) {
        self.searchBar.tintColor = self.navigationController.navigationBar.tintColor;
    }

    // Search text field appearance
    UITextField *searchTextField = [self.searchBar valueForKey:@"searchField"];
    searchTextField.textColor = [UIColor colorWithRed:0.35 green:0.96 blue:0.31 alpha:1.0];
    searchTextField.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1.0];
    searchTextField.attributedPlaceholder = [[NSAttributedString alloc]
        initWithString:@"Search songs or artists"
            attributes:@{NSForegroundColorAttributeName: [UIColor colorWithRed:0.35 green:0.96 blue:0.31 alpha:0.5]}];

    // Dismiss keyboard when scrolling or tapping the table
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    UITapGestureRecognizer *tableTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    tableTap.cancelsTouchesInView = NO;
    [self.tableView addGestureRecognizer:tableTap];

    self.allSongs = [MusicLibrary sharedLibrary].songs;
    self.filteredSongs = self.allSongs;

    [self setupMiniPlayer];
    [self updateMiniPlayer];

    // Keyboard notifications to raise the mini player
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.miniPlayerView.hidden = NO;
    self.allSongs = [MusicLibrary sharedLibrary].songs;
    [self filterSongsWithSearchText:self.searchBar.text];
    [self updateMiniPlayer];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.miniPlayerView.hidden = YES;
}

#pragma mark - Keyboard

- (void)keyboardWillShow:(NSNotification *)notification {
    CGRect keyboardFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect keyboardInView = [self.navigationController.view convertRect:keyboardFrame fromView:nil];
    CGFloat overlap = CGRectGetMaxY(self.miniPlayerView.frame) - keyboardInView.origin.y;
    if (overlap <= 0) return;

    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    [UIView animateWithDuration:duration animations:^{
        self.miniPlayerView.transform = CGAffineTransformMakeTranslation(0, -overlap);
        UIEdgeInsets inset = self.tableView.contentInset;
        inset.bottom = overlap + self.miniPlayerView.frame.size.height;
        self.tableView.contentInset = inset;
        self.tableView.scrollIndicatorInsets = inset;
    }];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    [UIView animateWithDuration:duration animations:^{
        self.miniPlayerView.transform = CGAffineTransformIdentity;
        UIEdgeInsets inset = self.tableView.contentInset;
        inset.bottom = self.miniPlayerView.frame.size.height;
        self.tableView.contentInset = inset;
        self.tableView.scrollIndicatorInsets = inset;
    }];
}

- (void)rescan {
    [[MusicLibrary sharedLibrary] rescan];
    self.allSongs = [MusicLibrary sharedLibrary].songs;
    [self filterSongsWithSearchText:self.searchBar.text];

    if ([MusicLibrary sharedLibrary].songs.count == 0) {
        [self showFolderPath];
    }
}

#pragma mark - Search

- (void)filterSongsWithSearchText:(NSString *)searchText {
    if (searchText.length == 0) {
        self.filteredSongs = self.allSongs;
    } else {
        NSMutableArray *result = [NSMutableArray array];
        for (Song *song in self.allSongs) {
            BOOL titleMatch = [song.title rangeOfString:searchText options:NSCaseInsensitiveSearch].location != NSNotFound;
            BOOL artistMatch = [song.artist rangeOfString:searchText options:NSCaseInsensitiveSearch].location != NSNotFound;
            if (titleMatch || artistMatch) {
                [result addObject:song];
            }
        }
        self.filteredSongs = result;
    }
    [self.tableView reloadData];
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    [self filterSongsWithSearchText:searchText];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    searchBar.text = @"";
    [self filterSongsWithSearchText:@""];
    [searchBar resignFirstResponder];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    self.searchBarActive = YES;
    [searchBar setShowsCancelButton:YES animated:YES];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar {
    self.searchBarActive = NO;
    [searchBar setShowsCancelButton:NO animated:YES];
}

- (void)dismissKeyboard {
    [self.searchBar resignFirstResponder];
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (self.searchBarActive) {
        CGFloat minOffset = -scrollView.contentInset.top;
        if (scrollView.contentOffset.y < minOffset) {
            scrollView.contentOffset = CGPointMake(0, minOffset);
        }
    }
}

- (void)showFolderPath {
    NSString *path = [MusicLibrary sharedLibrary].musicDirectory;
    UIAlertView *alert = [[UIAlertView alloc]
        initWithTitle:@"Music Folder"
              message:[NSString stringWithFormat:@"Use Filza to copy mp3/m4a/ogg files into:\n\n%@\n\nThen tap the refresh button.", path]
             delegate:nil
    cancelButtonTitle:@"OK"
    otherButtonTitles:nil];
    [alert show];
}

#pragma mark - Mini Player

- (void)setupMiniPlayer {
    CGFloat height = 50;

    UIColor *greenColor = [UIColor colorWithRed:0.35 green:0.96 blue:0.31 alpha:1.0];

    // Use navigation controller's view so the bar stays fixed (doesn't scroll with table)
    UIView *parentView = self.navigationController.view;
    CGRect parentFrame = parentView.bounds;

    self.miniPlayerView = [[UIView alloc] initWithFrame:CGRectMake(0, parentFrame.size.height - height, parentFrame.size.width, height)];
    self.miniPlayerView.backgroundColor = [UIColor colorWithWhite:0.08 alpha:1.0];
    self.miniPlayerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;

    // Top border
    UIView *topBorder = [[UIView alloc] initWithFrame:CGRectMake(0, 0, parentFrame.size.width, 0.5)];
    topBorder.backgroundColor = greenColor;
    topBorder.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.miniPlayerView addSubview:topBorder];

    // Song label (tap to open Now Playing)
    CGFloat labelWidth = parentFrame.size.width - 90;
    self.miniPlayerLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 0, labelWidth, height)];
    self.miniPlayerLabel.font = [UIFont systemFontOfSize:14];
    self.miniPlayerLabel.textColor = greenColor;
    self.miniPlayerLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.miniPlayerLabel.userInteractionEnabled = YES;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(openNowPlaying)];
    [self.miniPlayerLabel addGestureRecognizer:tap];
    [self.miniPlayerView addSubview:self.miniPlayerLabel];

    // Play / Pause button (smaller)
    self.miniPlayerPlayPauseButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.miniPlayerPlayPauseButton.frame = CGRectMake(parentFrame.size.width - 60, 10, 44, 30);
    self.miniPlayerPlayPauseButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    self.miniPlayerPlayPauseButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
    [self.miniPlayerPlayPauseButton setImage:[[UIImage imageNamed:@"play2"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    [self.miniPlayerPlayPauseButton setImage:[[UIImage imageNamed:@"pause2"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateSelected];
    self.miniPlayerPlayPauseButton.tintColor = greenColor;
    [self.miniPlayerPlayPauseButton addTarget:self action:@selector(togglePlayPause) forControlEvents:UIControlEventTouchUpInside];
    [self.miniPlayerView addSubview:self.miniPlayerPlayPauseButton];

    [parentView addSubview:self.miniPlayerView];
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, height, 0);
}

- (void)updateMiniPlayer {
    Song *song = [[PlayerController sharedPlayer] currentSong];
    if (song) {
        self.miniPlayerLabel.text = [NSString stringWithFormat:@"%@ — %@", song.title, song.artist];
    } else {
        self.miniPlayerLabel.text = @"No song playing";
    }
    BOOL playing = [PlayerController sharedPlayer].isPlaying;
    self.miniPlayerPlayPauseButton.selected = playing;
    UIImage *icon = playing ? [UIImage imageNamed:@"pause2"] : [UIImage imageNamed:@"play2"];
    [self.miniPlayerPlayPauseButton setImage:[icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
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
    return self.filteredSongs.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"SongCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
        // iOS 7+ disclosure indicator style
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    Song *song = self.filteredSongs[indexPath.row];
    cell.textLabel.text = song.title;
    cell.detailTextLabel.text = song.artist;

    // Dark theme
    UIColor *greenColor = [UIColor colorWithRed:0.35 green:0.96 blue:0.31 alpha:1.0];
    cell.backgroundColor = [UIColor blackColor];
    cell.textLabel.textColor = greenColor;
    cell.detailTextLabel.textColor = [UIColor colorWithRed:0.35 green:0.96 blue:0.31 alpha:0.7];
    cell.tintColor = greenColor;

    // Selected background
    UIView *selBg = [[UIView alloc] init];
    selBg.backgroundColor = [UIColor colorWithRed:0.35 green:0.96 blue:0.31 alpha:0.15];
    cell.selectedBackgroundView = selBg;

    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [[PlayerController sharedPlayer] playQueue:self.filteredSongs startingAtIndex:indexPath.row];
    [self updateMiniPlayer];
}

@end
