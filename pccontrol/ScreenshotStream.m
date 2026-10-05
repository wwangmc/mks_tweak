#import "ScreenshotStream.h"
#import "Screen.h"

@interface MKSScreenshotStreamState : NSObject
@property(atomic) BOOL closed;
@property(nonatomic) NSTimeInterval nextFrameTime;
@end

@implementation MKSScreenshotStreamState
@end

@interface MKSScreenshotStream ()
@property(nonatomic, strong) MKSScreenshotStreamState *streamState;
@end

@implementation MKSScreenshotStream

+ (instancetype)responseWithQuality:(CGFloat)quality fps:(NSUInteger)fps {
    MKSScreenshotStreamState *state = [MKSScreenshotStreamState new];
    dispatch_queue_t queue = dispatch_queue_create("com.csmk.screenshot-stream", DISPATCH_QUEUE_SERIAL);
    NSTimeInterval interval = 1.0 / fps;
    MKSScreenshotStream *response = [[self alloc]
        initWithContentType:@"multipart/x-mixed-replace; boundary=frame"
        asyncStreamBlock:^(GCDWebServerBodyReaderCompletionBlock completion) {
            dispatch_async(queue, ^{
                NSTimeInterval delay = MAX(0, state.nextFrameTime - NSProcessInfo.processInfo.systemUptime);
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), queue, ^{
                    @autoreleasepool {
                        if (state.closed) {
                            completion([NSData data], nil);
                            return;
                        }
                        state.nextFrameTime = NSProcessInfo.processInfo.systemUptime + interval;
                        NSData *image = [Screen takeScreenshotWithQuality:quality];
                        if (state.closed) {
                            completion([NSData data], nil);
                            return;
                        }
                        if (!image.length) {
                            NSError *error = [NSError errorWithDomain:@"com.csmk.screenshot" code:500
                                userInfo:@{NSLocalizedDescriptionKey: @"Failed to capture screen"}];
                            completion(nil, error);
                            return;
                        }
                        NSString *header = [NSString stringWithFormat:
                            @"--frame\r\nContent-Type: image/jpeg\r\nContent-Length: %lu\r\n\r\n",
                            (unsigned long)image.length];
                        NSData *headerData = [header dataUsingEncoding:NSUTF8StringEncoding];
                        NSMutableData *frame = [NSMutableData dataWithCapacity:headerData.length + image.length + 2];
                        [frame appendData:headerData];
                        [frame appendData:image];
                        [frame appendBytes:"\r\n" length:2];
                        completion(frame, nil);
                    }
                });
            });
        }];
    response.streamState = state;
    [response setValue:@"no-store" forAdditionalHeader:@"Cache-Control"];
    return response;
}

- (void)close {
    self.streamState.closed = YES;
    [super close];
}

@end
