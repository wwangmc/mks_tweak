#include "Screen.h"
#include "Common.h"
#import <UIKit/UIKit.h>

// #import "headers/IOKitSPI.h"
#import <IOSurface/IOSurfaceRef.h>

// 像素高度及宽度
static CGFloat device_screen_width = 0;
static CGFloat device_screen_height = 0;

// 实际高度及宽度
static CGFloat device_screen_pt_width = 0;
static CGFloat device_screen_pt_height = 0;
static CGSize portraitSize;

static CGFloat device_screen_scale = 0;
OBJC_EXTERN void CARenderServerRenderDisplay(kern_return_t a, CFStringRef b, IOSurfaceRef surface, int x, int y);
OBJC_EXTERN CGImageRef UICreateCGImageFromIOSurface(IOSurfaceRef surface);

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
        portraitSize = CGSizeMake(device_screen_pt_width,
                                device_screen_pt_height);
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

+ (NSData *)takeScreenshotWithQuality_v2:(CGFloat)quality {
    NSLog(@"take a screenshot");
    CGImageRef imageRef = [Screen createScreenShotCGImageRef];
    UIImage *image = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    return UIImageJPEGRepresentation(image,quality);
}

+ (NSData *)takeScreenshotWithQuality:(CGFloat)quality {
    NSLog(@"take a screenshot");
    UIGraphicsBeginImageContextWithOptions(portraitSize, NO, device_screen_scale);
    
    for (UIWindow *window in [[UIApplication sharedApplication] windows]) {
        [window drawViewHierarchyInRect:window.bounds afterScreenUpdates:NO];
    }
    
    UIImage *screenshot = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return UIImageJPEGRepresentation(screenshot, quality);
}
+ (NSData *)takeScreenshot_v2 {
    CGImageRef imageRef = [Screen createScreenShotCGImageRef];
    UIImage *image = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    return UIImagePNGRepresentation(image);
}
+ (NSData *)takeScreenshot {
    UIGraphicsBeginImageContextWithOptions(portraitSize, NO, device_screen_scale);
    
    for (UIWindow *window in [[UIApplication sharedApplication] windows]) {
        [window drawViewHierarchyInRect:window.bounds afterScreenUpdates:NO];
    }
    
    UIImage *screenshot = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return UIImagePNGRepresentation(screenshot);
}
+ (CGImageRef)createScreenShotCGImageRef {
    // 静态变量（只计算一次）
    static int bytesPerElement = 4;
    static int bytesPerRow;
    static NSNumber *IOSurfaceBytesPerElement;
    static NSNumber *IOSurfaceBytesPerRow;
    static NSNumber *IOSurfaceAllocSize;
    static NSNumber *nheight;
    static NSNumber *nwidth;
    static NSNumber *IOSurfacePixelFormat;
    static NSNumber *IOSurfaceIsGlobal;
    static NSDictionary *propertiesTemplate;

    // 使用 dispatch_once 确保线程安全初始化
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        bytesPerRow = roundUp(bytesPerElement * device_screen_width, 32);
        
        // 缓存 NSNumber 对象（避免重复创建）
        IOSurfaceBytesPerElement = @(bytesPerElement);
        IOSurfaceBytesPerRow = @(bytesPerRow);
        IOSurfaceAllocSize = @(bytesPerRow * device_screen_height);
        nheight = @(device_screen_height);
        nwidth = @(device_screen_width);
        IOSurfacePixelFormat = @(1111970369); // 固定值
        IOSurfaceIsGlobal = @(1); // 固定值

        // 字典模板（避免每次重新构建）
        propertiesTemplate = @{
            @"IOSurfaceAllocSize": IOSurfaceAllocSize,
            @"IOSurfaceBytesPerElement": IOSurfaceBytesPerElement,
            @"IOSurfaceBytesPerRow": IOSurfaceBytesPerRow,
            @"IOSurfaceHeight": nheight,
            @"IOSurfaceIsGlobal": IOSurfaceIsGlobal,
            @"IOSurfacePixelFormat": IOSurfacePixelFormat,
            @"IOSurfaceWidth": nwidth
        };
    });

    // 创建 IOSurface
    IOSurfaceRef screenSurface = IOSurfaceCreate((__bridge CFDictionaryRef)propertiesTemplate);
    if (!screenSurface) return nil;

    // 渲染截图
    IOSurfaceLock(screenSurface, 0, NULL);
    CARenderServerRenderDisplay(0, CFSTR("LCD"), screenSurface, 0, 0);

    // 转换为 CGImage
    CGImageRef cgImageRef = UICreateCGImageFromIOSurface(screenSurface);
    
    // 清理
    IOSurfaceUnlock(screenSurface, 0, NULL);
    CFRelease(screenSurface);

    return cgImageRef;
}
@end

