#import "VolumeButtons.h"
#import <MediaPlayer/MediaPlayer.h>

@implementation VolumeButtons {
    MPVolumeView *volumeView;
    float initialVolume;
    BOOL volumeButtonPressed;
}

- (void)pluginInitialize {
    [super pluginInitialize];
    
    volumeView = [[MPVolumeView alloc] initWithFrame:CGRectZero];
    [[UIApplication sharedApplication].keyWindow addSubview:volumeView];
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

- (void)createInvisibleAudioPlayer {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"silence" ofType:@"mp3"];
    NSURL *url = [NSURL fileURLWithPath:path];

    AVAudioPlayer *audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];
    audioPlayer.volume = initialVolume;
    [audioPlayer play];
}

- (void)volumeChanged:(NSNotification *)notification {
    if (!volumeButtonPressed) {
        volumeButtonPressed = YES;
        [self resetVolume];
        volumeButtonPressed = NO;
        [self sendVolumeButtonPressed];
    }
}

- (void)resetVolume {
    MPMusicPlayerController *mpc = [MPMusicPlayerController applicationMusicPlayer];
    [mpc setVolume:initialVolume];
}

- (void)sendVolumeButtonPressed {
    [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK] callbackId:self.callbackId];
}

- (void)onVolumeButtonPressed:(CDVInvokedUrlCommand*)command {
    self.callbackId = command.callbackId;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
