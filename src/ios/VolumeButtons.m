#import "VolumeButtons.h"
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>

// (VBMode enum is in your .h)

@implementation VolumeButtons {
    MPVolumeView  *volumeView;
    AVAudioPlayer *silentPlayer;
    float          baselineVolume;
    float          detectionVolume;
    NSTimer       *resetTimer;
}

#pragma mark – Plugin Init

- (void)pluginInitialize {
    [super pluginInitialize];
    NSLog(@"VolumeButtons: Initializing plugin");

    // 1) Activate playback session
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *err = nil;
    [session setCategory:AVAudioSessionCategoryPlayback
             withOptions:AVAudioSessionCategoryOptionMixWithOthers
                   error:&err];
    [session setActive:YES error:&err];
    if (err) NSLog(@"VolumeButtons: Audio session error: %@", err.localizedDescription);

    // 2) Set up baseline & detection volumes
    baselineVolume  = session.outputVolume;
    detectionVolume = baselineVolume;
    NSLog(@"VolumeButtons: baselineVolume = %.2f", baselineVolume);

    // 3) Add MPVolumeView (we’ll re-add/remove it per mode)
    volumeView = [[MPVolumeView alloc] initWithFrame:CGRectZero];

    // 4) Observe changes
    [session addObserver:self
              forKeyPath:@"outputVolume"
                 options:NSKeyValueObservingOptionNew
                 context:NULL];

    // 5) Loop silent audio
    [self createSilentAudioLoop];

    // 6) Default mode
    self.currentMode = VBModeAggressive;
    [self updateVolumeViewForMode];
}

- (void)dealloc {
    [[AVAudioSession sharedInstance] removeObserver:self forKeyPath:@"outputVolume"];
}

#pragma mark – KVO Callback

- (void)observeValueForKeyPath:(NSString*)keyPath
                      ofObject:(id)object
                        change:(NSDictionary*)change
                       context:(void*)context
{
    if (![keyPath isEqualToString:@"outputVolume"]) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }

    float newVol = [change[NSKeyValueChangeNewKey] floatValue];
    // ignore our reset
    if (newVol == baselineVolume) return;

    // detect direction
    NSString *dir = (newVol > detectionVolume) ? @"up" : @"down";
    detectionVolume = newVol;
    NSLog(@"VolumeButtons: Detected %@", dir);

    // send to JS if not in 'none'
    if (self.currentMode != VBModeNone && self.callbackId) {
        CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                messageAsString:dir];
        [res setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:res callbackId:self.callbackId];
    }

    // schedule a single reset back to baseline
    [resetTimer invalidate];
    resetTimer = [NSTimer scheduledTimerWithTimeInterval:0.2
                                                  target:self
                                                selector:@selector(resetVolume)
                                                userInfo:nil
                                                 repeats:NO];
}

#pragma mark – Volume Reset

- (void)resetVolume {
    // only in aggressive mode
    if (self.currentMode != VBModeAggressive) return;

    for (UIView *v in volumeView.subviews) {
        if ([v isKindOfClass:[UISlider class]]) {
            [(UISlider*)v setValue:baselineVolume animated:NO];
            break;
        }
    }
    // restore for next detection cycle
    detectionVolume = baselineVolume;
}

#pragma mark – Silent Audio

- (void)createSilentAudioLoop {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"silence" ofType:@"mp3"];
    NSLog(@"VolumeButtons: Loading silent audio from %@", path);
    if (!path) { NSLog(@"VolumeButtons: ⚠️ silence.mp3 not found"); return; }

    NSURL *url = [NSURL fileURLWithPath:path];
    NSError *err = nil;
    silentPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&err];
    if (err) { NSLog(@"VolumeButtons: Silent player init error: %@", err.localizedDescription); return; }
    silentPlayer.numberOfLoops = -1;
    silentPlayer.volume = baselineVolume;
    BOOL ok = [silentPlayer play];
    NSLog(@"VolumeButtons: silentPlayer play returned %d, isPlaying:%d", ok, silentPlayer.isPlaying);
}

#pragma mark – Mode Management

- (void)setMonitoringMode:(CDVInvokedUrlCommand*)command {
    NSString *m = command.arguments.firstObject ?: @"aggressive";
    if ([m isEqualToString:@"silent"])    self.currentMode = VBModeSilent;
    else if ([m isEqualToString:@"none"]) self.currentMode = VBModeNone;
    else                                  self.currentMode = VBModeAggressive;

    [self updateVolumeViewForMode];
    NSLog(@"VolumeButtons: Mode = %@", m);

    CDVPluginResult *r = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:r callbackId:command.callbackId];
}

- (void)setBaselineVolume:(CDVInvokedUrlCommand*)command {
    if (command.arguments.count == 0) {
        CDVPluginResult *err = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Missing volume"];
        [self.commandDelegate sendPluginResult:err callbackId:command.callbackId];
        return;
    }

    float newBaseline = [command.arguments[0] floatValue];
    if (newBaseline < 0.0 || newBaseline > 1.0) {
        CDVPluginResult *err = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Volume must be between 0.0 and 1.0"];
        [self.commandDelegate sendPluginResult:err callbackId:command.callbackId];
        return;
    }

    baselineVolume = newBaseline;
    detectionVolume = baselineVolume;

    NSLog(@"VolumeButtons: New baseline volume set to %.2f", baselineVolume);

    // Apply immediately if in aggressive mode
    if (self.currentMode == VBModeAggressive) {
        for (UIView *v in volumeView.subviews) {
            if ([v isKindOfClass:[UISlider class]]) {
                [(UISlider*)v setValue:baselineVolume animated:NO];
                break;
            }
        }
    }

    CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
}


- (void)updateVolumeViewForMode {
    UIWindow *win = [self getMainWindow];
    UIView *parent = win.rootViewController.view;

    [volumeView removeFromSuperview];
    if (self.currentMode == VBModeAggressive) {
        volumeView.alpha = 0.01;
        [parent addSubview:volumeView];
    }
    // silent & none → no MPVolumeView → system HUD appears
}

#pragma mark – JS Bridge

- (void)onVolumeButtonPressed:(CDVInvokedUrlCommand*)command {
    NSLog(@"VolumeButtons: JS callback registered");
    self.callbackId = command.callbackId;
}

#pragma mark – Helpers

- (UIWindow*)getMainWindow {
    if (@available(iOS 13.0, *)) {
        for (UIScene *sc in [UIApplication sharedApplication].connectedScenes) {
            if (sc.activationState == UISceneActivationStateForegroundActive &&
                [sc isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *ws = (UIWindowScene*)sc;
                if (ws.windows.count) return ws.windows.firstObject;
            }
        }
    }
    UIWindow *k = [UIApplication sharedApplication].keyWindow;
    return k ?: [UIApplication sharedApplication].windows.firstObject;
}

@end

