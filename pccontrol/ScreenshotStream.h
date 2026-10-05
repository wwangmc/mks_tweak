#import <GCDWebServers/GCDWebServerStreamedResponse.h>

@interface MKSScreenshotStream : GCDWebServerStreamedResponse
+ (instancetype)responseWithQuality:(CGFloat)quality fps:(NSUInteger)fps;
@end
