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
    NSTimeInterval lastEventTime;
}

#pragma mark – Plugin Init

- (void)pluginInitialize {
    [super pluginInitialize];
    NSLog(@"VolumeButtons: Initializing plugin");

    // 1) Initialize Session & Observers
    // We break this out into a method so we can call it again after interruptions
    [self restoreAudioSession];

    // 2) Set up baseline & detection volumes
    baselineVolume  = [[AVAudioSession sharedInstance] outputVolume];
    detectionVolume = baselineVolume;
    NSLog(@"VolumeButtons: baselineVolume = %.2f", baselineVolume);

    // 3) Add MPVolumeView (we’ll re-add/remove it per mode)
    volumeView = [[MPVolumeView alloc] initWithFrame:CGRectZero];

    // 4) Observe Volume changes
    [[AVAudioSession sharedInstance] addObserver:self
              forKeyPath:@"outputVolume"
                 options:NSKeyValueObservingOptionNew
                 context:NULL];

    // 5) Register for Lifecycle & Interruption Notifications (THE FIX)
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onAudioSessionInterruption:)
                                                 name:AVAudioSessionInterruptionNotification
                                               object:[AVAudioSession sharedInstance]];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onAppDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];

    // 6) Loop silent audio
    [self createSilentAudioLoop];

    // 7) Default mode
    self.currentMode = VBModeAggressive;
    [self updateVolumeViewForMode];
    
    // Initialize timestamp
    lastEventTime = -1;
}

- (void)dealloc {
    [[AVAudioSession sharedInstance] removeObserver:self forKeyPath:@"outputVolume"];
    [[NSNotificationCenter defaultCenter] removeObserver:self]; // Clean up new observers
}

#pragma mark – Audio Session Management (New Helpers)

- (void)restoreAudioSession {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *err = nil;
    
    // We re-apply this category because other plugins (like Media) likely removed the "MixWithOthers" option
    [session setCategory:AVAudioSessionCategoryPlayback
             withOptions:AVAudioSessionCategoryOptionMixWithOthers
                   error:&err];
    
    [session setActive:YES error:&err];
    
    if (err) NSLog(@"VolumeButtons: Audio session restore error: %@", err.localizedDescription);
}

- (void)checkAndResumeSilentPlayer {
    if (self.currentMode == VBModeNone) return;
    
    // If player exists but is stopped (due to interruption), restart it
    if (silentPlayer && !silentPlayer.isPlaying) {
        NSLog(@"VolumeButtons: Restarting silent player after interruption");
        [silentPlayer play];
    }
}

#pragma mark – Notification Handlers (The Fix)

- (void)onAudioSessionInterruption:(NSNotification *)notification {
    NSDictionary *info = notification.userInfo;
    NSUInteger type = [[info objectForKey:AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];

    if (type == AVAudioSessionInterruptionTypeBegan) {
        NSLog(@"VolumeButtons: Audio Session Interruption Began (Control lost)");
        // Another plugin or phone call took over. We just wait.
    } 
    else if (type == AVAudioSessionInterruptionTypeEnded) {
        NSLog(@"VolumeButtons: Audio Session Interruption Ended (Regaining control)");
        NSTimeInterval options = [[info objectForKey:AVAudioSessionInterruptionOptionKey] doubleValue];
        
        // Always try to restore our session settings
        [self restoreAudioSession];

        // Resume playing if the OS says we should, or if we just want to force it
        if (options == AVAudioSessionInterruptionOptionShouldResume || self.currentMode != VBModeNone) {
            [self checkAndResumeSilentPlayer];
        }
    }
}

- (void)onAppDidBecomeActive:(NSNotification *)notification {
    // This handles the case you mentioned: switching foreground/background fixes it.
    // We automate that fix here.
    NSLog(@"VolumeButtons: App Became Active");
    [self restoreAudioSession];
    [self checkAndResumeSilentPlayer];
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
    
    // Compute delta ms
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970] * 1000;
    NSTimeInterval delta = (lastEventTime < 0) ? 0 : (now - lastEventTime);
    lastEventTime = now;

    // Send raw event
    if (self.callbackId && self.currentMode != VBModeNone) {
        NSDictionary *payload = @{
            @"direction": dir,
            @"delta":     @(delta)
        };
        CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                              messageAsDictionary:payload];
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

- (void)getCurrentVolume:(CDVInvokedUrlCommand*)command {
    BOOL setAsBaseline = NO;
    if (command.arguments.count > 0) {
        setAsBaseline = [command.arguments[0] boolValue];
    }

    float currentVolume = [[AVAudioSession sharedInstance] outputVolume];
    NSLog(@"VolumeButtons: Current volume is %.2f", currentVolume);

    if (setAsBaseline) {
        baselineVolume  = currentVolume;
        detectionVolume = currentVolume;
        NSLog(@"VolumeButtons: Baseline volume set to %.2f", baselineVolume);
    }

    CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                            messageAsDouble:currentVolume];
    [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
}

- (void)applyVolume:(float)value {
    value = fmaxf(0.0f, fminf(1.0f, value));
    dispatch_async(dispatch_get_main_queue(), ^{
        for (UIView *v in self->volumeView.subviews) {
            if ([v isKindOfClass:[UISlider class]]) {
                UISlider *slider = (UISlider *)v;
                [slider setValue:value animated:NO];
                [slider sendActionsForControlEvents:UIControlEventTouchUpInside];
                break;
            }
        }
        self->baselineVolume = value;
        self->detectionVolume = value;
    });
}

- (void)setVolume:(CDVInvokedUrlCommand*)command {
    float value = [command.arguments[0] floatValue];
    [self applyVolume:value];

    CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
}


- (void)increaseVolume:(CDVInvokedUrlCommand*)command {
    float delta = [command.arguments[0] floatValue];
    float newVolume = fmin(1.0f, baselineVolume + delta);
    [self applyVolume:newVolume];

    CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
}

- (void)decreaseVolume:(CDVInvokedUrlCommand*)command {
    float delta = [command.arguments[0] floatValue];
    float newVolume = fmax(0.0f, baselineVolume - delta);
    [self applyVolume:newVolume];

    CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
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
