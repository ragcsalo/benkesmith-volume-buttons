#import "VolumeButtons.h"
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>

@implementation VolumeButtons {
    MPVolumeView *volumeView;
    float previousVolume;
    BOOL volumeButtonPressed;
    AVAudioPlayer *silentPlayer;
}

- (void)pluginInitialize {
    [super pluginInitialize];
    NSLog(@"VolumeButtons: Initializing plugin");

    // 1) Configure and activate Playback audio session
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    NSError *error = nil;
    [audioSession setCategory:AVAudioSessionCategoryPlayback
                  withOptions:AVAudioSessionCategoryOptionMixWithOthers
                        error:&error];
    if (error) {
        NSLog(@"VolumeButtons: Audio session category error: %@", error.localizedDescription);
    }
    [audioSession setActive:YES error:&error];
    if (error) {
        NSLog(@"VolumeButtons: Audio session activation error: %@", error.localizedDescription);
    }

    // 2) Keep track of current volume
    previousVolume = audioSession.outputVolume;
    NSLog(@"VolumeButtons: Starting with initial volume = %.2f", previousVolume);

    // 3) Add an MPVolumeView to suppress the system HUD
    volumeView = [[MPVolumeView alloc] initWithFrame:CGRectZero];
    volumeView.alpha = 0.01;  // effectively invisible
    UIWindow *mainWindow = [self getMainWindow];
    UIViewController *rootVC = mainWindow.rootViewController;
    [rootVC.view addSubview:volumeView];

    // 4) Listen for system volume-change notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(volumeChanged:)
                                                 name:@"AVSystemController_SystemVolumeDidChangeNotification"
                                               object:nil];

    // 5) Start playing silent audio in loop to keep session alive
    [self createSilentAudioLoop];
}

- (UIWindow *)getMainWindow {
    // iOS 13+ multi-scene support
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive &&
                [scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *ws = (UIWindowScene *)scene;
                if (ws.windows.count > 0) {
                    return ws.windows.firstObject;
                }
            }
        }
    }
    // Fallback for earlier iOS
    UIWindow *win = [UIApplication sharedApplication].keyWindow;
    if (win) return win;
    return [UIApplication sharedApplication].windows.firstObject;
}

- (void)createSilentAudioLoop {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"silence" ofType:@"mp3"];
    NSLog(@"VolumeButtons: Loading silent audio from %@", path);
    if (!path) {
        NSLog(@"VolumeButtons: ⚠️ silence.mp3 not found in bundle!");
        return;
    }
    NSURL *url = [NSURL fileURLWithPath:path];
    NSError *err = nil;
    silentPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&err];
    if (err) {
        NSLog(@"VolumeButtons: Silent player init error: %@", err.localizedDescription);
        return;
    }
    silentPlayer.numberOfLoops = -1;              // loop indefinitely
    silentPlayer.volume = previousVolume;         // match current volume
    BOOL ok = [silentPlayer play];
    NSLog(@"VolumeButtons: silentPlayer play returned %d, isPlaying: %d", ok, silentPlayer.isPlaying);
}

- (void)volumeChanged:(NSNotification *)notification {
    NSDictionary *info = notification.userInfo;
    float newVolume = [info[@"AVSystemController_AudioVolumeNotificationParameter"] floatValue];
    NSLog(@"VolumeButtons: Volume changed from %.2f to %.2f", previousVolume, newVolume);

    NSString *direction = nil;
    if (newVolume > previousVolume) {
        direction = @"up";
    } else if (newVolume < previousVolume) {
        direction = @"down";
    }
    previousVolume = newVolume;

    [self resetVolume];

    if (direction && self.callbackId) {
        NSLog(@"VolumeButtons: Detected volume %@", direction);
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                   messageAsString:direction];
        [self.commandDelegate sendPluginResult:result callbackId:self.callbackId];
    }
}

- (void)resetVolume {
    for (UIView *v in volumeView.subviews) {
        if ([v isKindOfClass:[UISlider class]]) {
            UISlider *slider = (UISlider *)v;
            [slider setValue:previousVolume animated:NO];
            break;
        }
    }
}

- (void)onVolumeButtonPressed:(CDVInvokedUrlCommand *)command {
    NSLog(@"VolumeButtons: JavaScript registered for volume button press event");
    self.callbackId = command.callbackId;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
