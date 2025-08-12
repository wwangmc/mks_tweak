#ifndef SCREEN_H
#define SCREEN_H
#import <UIKit/UIKit.h>
#import <GCDWebServers/GCDWebServerStreamedResponse.h>


@interface Screen :NSObject
+ (void)setScreenSize:(CGFloat)x height:(CGFloat) y;
+ (void)setScreenPTSize:(CGFloat)x height:(CGFloat) y;
+ (void)setScreenScale:(CGFloat) scale;
+ (int)getScreenOrientation;
+ (CGFloat)getScreenWidth;
+ (CGFloat)getScreenHeight;
+ (CGFloat)getScale;
+ (CGRect)getBounds;
+ (NSData *)takeScreenshotWithQuality:(CGFloat)quality;
+ (NSData *)takeScreenshotWithQuality_v2:(CGFloat)quality;
+ (NSData *)takeScreenshot;
@end

// NSData *imageFromSurface();
NSData *takeScreenshotFromSpringBoard(CGFloat quality);

#endif
