// The host regression tests use a screen stub instead of UIKit or private iOS APIs.
#ifndef SCREEN_H
#define SCREEN_H
#import <Foundation/Foundation.h>
@interface Screen : NSObject
+ (NSData *)takeScreenshotWithQuality:(CGFloat)quality;
@end
#endif
