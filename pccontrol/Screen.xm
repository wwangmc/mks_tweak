#include "Screen.h"
#include "Common.h"

#include "headers/IOSurface/IOSurfaceAccelerator.h"
#include "headers/IOSurface/IOMobileFramebuffer.h"
#import "headers/IOSurface/IOSurface.h"
#include "headers/IOSurface/CoreSurface.h"

OBJC_EXTERN void CARenderServerRenderDisplay(kern_return_t a, CFStringRef b, IOSurfaceRef surface, int x, int y);
OBJC_EXTERN kern_return_t IOSurfaceLock(IOSurfaceRef buffer, IOSurfaceLockOptions options, uint32_t *seed);
OBJC_EXTERN kern_return_t IOSurfaceUnLock(IOSurfaceRef buffer, IOSurfaceLockOptions options, uint32_t *seed);
OBJC_EXTERN IOSurfaceRef IOSurfaceCreate(CFDictionaryRef dictionary);
OBJC_EXTERN CGImageRef UICreateCGImageFromIOSurface(IOSurfaceRef surface);
// 像素高度及宽度
static CGFloat device_screen_width = 0;
static CGFloat device_screen_height = 0;

// 实际高度及宽度
static CGFloat device_screen_pt_width = 0;
static CGFloat device_screen_pt_height = 0;

static CGFloat device_screen_scale = 0;

@implementation Screen
{
    // device screen size
}

+ (void)setScreenScale:(CGFloat) scale
{
	device_screen_scale = scale;

	if (device_screen_scale == 0 || device_screen_scale > 10000)
	{
		NSLog(@"com.zjx.springboard: Unable to initialze the screen scale.");
	}
}
/*
Get the size of the screen and set them.
*/
+ (void)setScreenPTSize:(CGFloat)x height:(CGFloat) y
{
	device_screen_pt_width = x;
	device_screen_pt_height = y;

	if (device_screen_pt_width == 0 || device_screen_pt_height == 0 || device_screen_pt_width > 10000 || device_screen_pt_height > 10000)
	{
		NSLog(@"com.zjx.springboard: Unable to initialze the screen pt size. screen width: %f, screen height: %f", device_screen_pt_width, device_screen_pt_height);
	}
	else
	{
        [Screen setScreenSize:x*device_screen_scale height:y*device_screen_scale];
	}
}

+ (void)setScreenSize:(CGFloat)x height:(CGFloat) y
{
	device_screen_width = x;
	device_screen_height = y;

	if (device_screen_width == 0 || device_screen_height == 0 || device_screen_width > 10000 || device_screen_height > 10000)
	{
		NSLog(@"com.zjx.springboard: Unable to initialze the screen size. screen width: %f, screen height: %f", device_screen_width, device_screen_height);
	}
	else
	{
        NSLog(@"com.zjx.springboard: successfully initialize the screen size. screen width: %f, screen height: %f", device_screen_width, device_screen_height);
	}
}

+ (int)getScreenOrientation
{
    __block int screenOrientation = -1;

    dispatch_sync(dispatch_get_main_queue(), ^{
        @try{
            SpringBoard *springboard = (SpringBoard*)[%c(SpringBoard) sharedApplication];
            screenOrientation = [springboard _frontMostAppOrientation];
            //NSLog(@"com.zjx.springboard: orientation %d", screenOrientation);
        }
        @catch (NSException *exception) {
            NSLog(@"com.zjx.springboard: Debug: %@", exception.reason);
        }
    }   
    );

    return screenOrientation;
}

+ (CGFloat)getScreenWidth
{
    if (device_screen_width == 0)
    {
        NSLog(@"com.zjx.springboard: Cannot get screen width. Maybe you call [Screen getScreenWidth] before springboard getting the screen size.");
    }
    return device_screen_width;
}

+ (CGFloat)getScreenHeight
{
    if (device_screen_height == 0)
    {
        NSLog(@"com.zjx.springboard: Cannot get screen height. Maybe you call [Screen getScreenHeight] before springboard getting the screen size.");
    }
    return device_screen_height;
}

+ (CGFloat)getScale
{    
    return device_screen_scale;
}

+ (CGRect)getBounds
{
    return [UIScreen mainScreen].bounds;
}

- (void)captureFrame:(CADisplayLink *)link {
    if (!self.isStreaming) return;
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            @autoreleasepool{
            NSData *frameData = [Screen takeScreenshotWithQuality:0.3];

            NSMutableData *chunk = [NSMutableData data];
            [chunk appendData:[[NSString stringWithFormat:@"--boundary\r\nContent-Type: image/jpeg\r\nContent-Length: %lu\r\n\r\n", (unsigned long)frameData.length] dataUsingEncoding:NSUTF8StringEncoding]];
            [chunk appendData:frameData];
            [chunk appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
            
            if (weakSelf.streamCompletionBlock) {
                weakSelf.streamCompletionBlock(chunk, nil);
            }
        }
    });
}

- (void)stopStreaming {
    self.isStreaming = NO;
    [self.displayLink invalidate];
    self.displayLink = nil;
}


+ (NSData *)takeScreenshotWithQuality:(CGFloat)quality {
 
    CGSize portraitSize = CGSizeMake(device_screen_pt_width,
                                    device_screen_pt_height);
    UIGraphicsBeginImageContextWithOptions(portraitSize, NO, device_screen_scale);
    
    for (UIWindow *window in [[UIApplication sharedApplication] windows]) {
        [window drawViewHierarchyInRect:window.bounds afterScreenUpdates:NO];
    }
    
    UIImage *screenshot = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return UIImageJPEGRepresentation(screenshot, quality);
}
/* ios13不适用
+ (NSData *)takeScreenshotWithQuality:(CGFloat)quality {
    // 始终使用竖屏大小（即宽小高大）
    CGSize portraitSize = CGSizeMake(device_screen_pt_width,
                                     device_screen_pt_height);
    
    NSArray<UIWindow *> *windows = [[UIApplication sharedApplication] windows];
    NSMutableArray<UIWindow *> *visibleWindows = [NSMutableArray array];

    for (UIWindow *window in windows) {
        if (!window.hidden && window.alpha > 0 && window.windowLevel >= UIWindowLevelNormal) {
            [visibleWindows addObject:window];
        }
    }

    UIGraphicsBeginImageContextWithOptions(portraitSize, NO, device_screen_scale);
    CGContextRef context = UIGraphicsGetCurrentContext();

    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    
    if (orientation == UIInterfaceOrientationLandscapeLeft) {
        CGContextTranslateCTM(context, 0, portraitSize.height);
        CGContextRotateCTM(context, -M_PI_2);
    } else if (orientation == UIInterfaceOrientationLandscapeRight) {
        CGContextTranslateCTM(context, portraitSize.width, 0);
        CGContextRotateCTM(context, M_PI_2);
    } else if (orientation == UIInterfaceOrientationPortraitUpsideDown) {
        CGContextTranslateCTM(context, portraitSize.width, portraitSize.height);
        CGContextRotateCTM(context, M_PI);
    }

    // 按窗口层级从后向前绘制
    for (UIWindow *window in [visibleWindows sortedArrayUsingComparator:^NSComparisonResult(UIWindow *w1, UIWindow *w2) {
        return [@(w2.windowLevel) compare:@(w1.windowLevel)];
    }]) {
        [window drawViewHierarchyInRect:window.bounds afterScreenUpdates:NO];
    }

    UIImage *screenshot = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return UIImageJPEGRepresentation(screenshot, quality);
}
*/
@end