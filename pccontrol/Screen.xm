#include "Screen.h"
#include "Common.h"
#import <UIKit/UIKit.h>

#include "headers/IOSurface/IOSurfaceAccelerator.h"
#include "headers/IOSurface/IOMobileFramebuffer.h"
#import "headers/IOSurface/IOSurface.h"
#include "headers/IOSurface/CoreSurface.h"
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
    UIGraphicsBeginImageContextWithOptions(portraitSize, NO, device_screen_scale);
    
    for (UIWindow *window in [[UIApplication sharedApplication] windows]) {
        [window drawViewHierarchyInRect:window.bounds afterScreenUpdates:YES];
    }
    
    UIImage *screenshot = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return UIImageJPEGRepresentation(screenshot, quality);
   
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
+ (NSData *)takeScreenshot {
    UIGraphicsBeginImageContextWithOptions(portraitSize, NO, device_screen_scale);
    
    for (UIWindow *window in [[UIApplication sharedApplication] windows]) {
        [window drawViewHierarchyInRect:window.bounds afterScreenUpdates:NO];
    }
    
    UIImage *screenshot = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return UIImagePNGRepresentation(screenshot);
}



@end


NSData *imageFromSurface() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    float scale = [UIScreen mainScreen].scale;
    
    NSInteger width, height;
    // setup the width and height of the framebuffer for the device
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        // iPhone frame buffer is Portrait
        width = screenSize.width * scale;
        height = screenSize.height * scale;
    } else {
        // iPad frame buffer is Landscape
        width = screenSize.height * scale;
        height = screenSize.width * scale;
    }
    
    NSInteger bytesPerElement = 4;
    NSInteger bytesPerRow = bytesPerElement * width;
    NSInteger totalBytes = bytesPerRow * height;

    NSDictionary *properties = @{
        (__bridge NSString *)kIOSurfaceIsGlobal:@YES,
        (__bridge NSString *)kIOSurfaceBytesPerElement:@(bytesPerElement),
        (__bridge NSString *)kIOSurfaceBytesPerRow:@(bytesPerRow),
        (__bridge NSString *)kIOSurfaceWidth:@(width),
        (__bridge NSString *)kIOSurfaceHeight:@(height),
        (__bridge NSString *)kIOSurfacePixelFormat:@(0x42475241),//'ARGB'
        (__bridge NSString *)kIOSurfaceAllocSize:@(bytesPerRow * height)
    };
    
    IOSurfaceRef surface = IOSurfaceCreate((__bridge CFDictionaryRef)properties);
    
    IOSurfaceLock(surface, 0, nil);
    CARenderServerRenderDisplay(0, CFSTR("LCD"), surface, 0, 0);
    void * baseAddr = IOSurfaceGetBaseAddress(surface);
    NSData * data = [NSData dataWithBytes:baseAddr length:totalBytes];
    IOSurfaceUnlock(surface, 0, 0);
    
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, data.bytes, data.length, NULL);
    CGImageRef imageRef = CGImageCreate(width, height, 8, 8*bytesPerElement, bytesPerRow,
                                        CGColorSpaceCreateDeviceRGB(),
                                        kCGBitmapByteOrder32Host | kCGImageAlphaFirst,
                                        provider, NULL, false, kCGRenderingIntentDefault);
    
    UIImage * image = [UIImage imageWithCGImage:imageRef];
    // UIImage *screenshot = imageFromSurface(surface);
    if (image) {
        NSData *pngData = UIImagePNGRepresentation(image);
        [pngData writeToFile:@"/var/mobile/screenshot.png" atomically:YES];
        // NSLog(@"截图已保存到 /var/mobile/screenshot.png");
    }
    CGImageRelease(imageRef);
    CFRelease(surface);
    
  });
}
