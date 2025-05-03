#import <Cordova/CDV.h>

@interface VolumeButtons : CDVPlugin

@property (nonatomic, strong) NSString *callbackId;

- (void)onVolumeButtonPressed:(CDVInvokedUrlCommand *)command;

@end
