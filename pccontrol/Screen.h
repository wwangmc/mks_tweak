#ifndef SCREEN_H
#define SCREEN_H
#import <UIKit/UIKit.h>
#include "GCDWebServerStreamedResponse.h"

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
@end

#endif
