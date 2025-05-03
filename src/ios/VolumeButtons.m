#import "VolumeButtons.h"
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>

@implementation VolumeButtons {
    MPVolumeView *volumeView;
    float previousVolume;
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
    previousVolume = audioSession.outputVolume;

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
    audioPlayer.volume = previousVolume;
    [audioPlayer play];
}

- (void)volumeChanged:(NSNotification *)notification {
    float newVolume = [[[notification userInfo]
                         objectForKey:@"AVSystemController_AudioVolumeNotificationParameter"] floatValue];

    NSLog(@"VolumeButtons: Volume changed from %.2f to %.2f", previousVolume, newVolume);

    NSString *direction = nil;
    if (newVolume > previousVolume) {
        direction = @"up";
    } else if (newVolume < previousVolume) {
        direction = @"down";
    }

    previousVolume = newVolume;

    [self resetVolume];

    if (direction != nil && self.callbackId != nil) {
        NSLog(@"VolumeButtons: Detected volume %@", direction);
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:direction];
        [self.commandDelegate sendPluginResult:result callbackId:self.callbackId];
    }
}

- (void)resetVolume {
    UISlider *volumeSlider = nil;
    for (UIView *view in volumeView.subviews) {
        if ([view isKindOfClass:[UISlider class]]) {
            volumeSlider = (UISlider *)view;
            break;
        }
    }
    if (volumeSlider != nil) {
        [volumeSlider setValue:previousVolume animated:NO];
    }
}

- (void)sendVolumeButtonPressed {
    // Deprecated, not used anymore
}

- (void)onVolumeButtonPressed:(CDVInvokedUrlCommand *)command {
    NSLog(@"VolumeButtons: JavaScript registered for volume button press event");
    self.callbackId = command.callbackId;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
