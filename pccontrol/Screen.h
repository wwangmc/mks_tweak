#ifndef SCREEN_H
#define SCREEN_H
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h> // 用于 CADisplayLink
#include "GCDWebServerStreamedResponse.h"

@interface Screen :NSObject
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, assign) BOOL isStreaming;
@property (nonatomic, copy) GCDWebServerBodyReaderCompletionBlock streamCompletionBlock;

- (void)captureFrame:(CADisplayLink *)link;
- (void)stopStreaming;
+ (void)setScreenSize:(CGFloat)x height:(CGFloat) y;
+ (int)getScreenOrientation;
+ (CGFloat)getScreenWidth;
+ (CGFloat)getScreenHeight;
+ (CGFloat)getScale;
+ (CGRect)getBounds;
+ (NSData *)takeScreenshotWithQuality:(CGFloat)quality;
@end

#endif
