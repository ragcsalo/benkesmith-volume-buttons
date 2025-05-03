#import "VolumeButtons.h"
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>

@implementation VolumeButtons {
    MPVolumeView *volumeView;
    float initialVolume;
    BOOL volumeButtonPressed;
}

- (void)pluginInitialize {
    [super pluginInitialize];
    
    NSLog(@"VolumeButtons: Initializing plugin");

    volumeView = [[MPVolumeView alloc] initWithFrame:CGRectZero];
    UIWindow *mainWindow = [self getMainWindow];
    [mainWindow addSubview:volumeView];
    volumeView.hidden = YES;

    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setActive:YES error:nil];
    initialVolume = audioSession.outputVolume;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(volumeChanged:)
                                                 name:@"AVSystemController_SystemVolumeDidChangeNotification"
                                               object:nil];

    [self createInvisibleAudioPlayer];
}

- (UIWindow *)getMainWindow {
    UIWindow *mainWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                mainWindow = scene.windows.firstObject;
                break;
            }
        }
    }
    if (!mainWindow) {
        if (@available(iOS 15.0, *)) {
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive) {
                    mainWindow = [scene.windows firstObject];
                    break;
                }
            }
        } else {
            mainWindow = [UIApplication sharedApplication].windows.firstObject;
        }
    }
    return mainWindow;
}

- (void)createInvisibleAudioPlayer {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"silence" ofType:@"mp3"];
    NSURL *url = [NSURL fileURLWithPath:path];

    AVAudioPlayer *audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];
    audioPlayer.volume = initialVolume;
    [audioPlayer play];
}

- (void)volumeChanged:(NSNotification *)notification {
    NSLog(@"VolumeButtons: Volume change detected");
    NSDictionary *userInfo = [notification userInfo];
    NSLog(@"VolumeButtons: UserInfo %@", userInfo);
    if (!volumeButtonPressed) {
        volumeButtonPressed = YES;
        [self resetVolume];
        volumeButtonPressed = NO;
        [self sendVolumeButtonPressed];
    }
}

- (void)resetVolume {
    NSLog(@"VolumeButtons: Resetting volume");
    UISlider *volumeSlider = nil;
    for (UIView *view in volumeView.subviews) {
        if ([view isKindOfClass:[UISlider class]]) {
            volumeSlider = (UISlider *)view;
            break;
        }
    }
    if (volumeSlider != nil) {
        [volumeSlider setValue:initialVolume animated:NO];
    } else {
        NSLog(@"VolumeButtons: Volume slider not found");
    }
}

- (void)sendVolumeButtonPressed {
    NSLog(@"VolumeButtons: Sending volume button press event to JavaScript");
    if (self.callbackId != nil) {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:result callbackId:self.callbackId];
    } else {
        NSLog(@"VolumeButtons: Callback ID is nil");
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
