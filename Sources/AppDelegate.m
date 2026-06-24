#import "AppDelegate.h"
#import "RootViewController.h"
#import <AVFoundation/AVFoundation.h>

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Lets audio keep playing when the screen locks or the app is backgrounded.
    NSError *error = nil;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&error];
    [[AVAudioSession sharedInstance] setActive:YES error:&error];

    // iOS 7+ appearance
    if ([UINavigationBar instancesRespondToSelector:@selector(setBarTintColor:)]) {
        [[UINavigationBar appearance] setBarTintColor:[UIColor colorWithRed:0.11 green:0.11 blue:0.13 alpha:1.0]];
        [[UINavigationBar appearance] setTintColor:[UIColor whiteColor]];
        [[UINavigationBar appearance] setTitleTextAttributes:@{
            NSForegroundColorAttributeName: [UIColor whiteColor]
        }];
        [[UINavigationBar appearance] setTranslucent:NO];
        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
    }

    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

    RootViewController *root = [[RootViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:root];

    self.window.rootViewController = nav;
    [self.window makeKeyAndVisible];

    return YES;
}

@end
