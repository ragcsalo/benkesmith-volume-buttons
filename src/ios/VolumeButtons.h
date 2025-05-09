#import <Cordova/CDV.h>

typedef NS_ENUM(NSInteger, VBMode) {
    VBModeAggressive = 0,
    VBModeSilent     = 1,
    VBModeNone       = 2
};

@interface VolumeButtons : CDVPlugin

@property (nonatomic, strong) NSString *callbackId;
@property (nonatomic, assign) VBMode     currentMode;

// JS‐exposed
- (void)onVolumeButtonPressed:(CDVInvokedUrlCommand*)command;
- (void)setMonitoringMode:(CDVInvokedUrlCommand*)command;
- (void)setBaselineVolume:(CDVInvokedUrlCommand*)command;
- (void)getCurrentVolume:(CDVInvokedUrlCommand*)command;

@end

