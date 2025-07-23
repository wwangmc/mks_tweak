#import "SocketHandler.h"
#import <Foundation/NSDistributedNotificationCenter.h>
#import "Process.h"
#import "Request.h"
#import "Screen.h"
static NSTimer *_globalTimer;
@interface SocketHandler ()
@end

@implementation SocketHandler

-(void)onData:(NSData *)data{
    [self sendData:data opcode:OPCODE_BINARY];
}

-(void)onText:(NSString *)text{
    [self sendText:text];
}

-(void)onClosed{
    [self stopTimer];

}
-(void)onError:(NSError*)error{
    // 输出异常信息后 和close走一样逻辑
    NSLog(@"Socket error: %@", error);
    [self stopTimer];
}
-(void)onConnected{
    [self startTimer];
}

- (void)startTimer {
    [self stopTimer];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        _globalTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                              target:self
                                                            selector:@selector(handleTimer)
                                                            userInfo:nil
                                                             repeats:YES];
    });
}

- (void)stopTimer {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (_globalTimer) {
            [_globalTimer invalidate];
            _globalTimer = nil;
        }
    });
}

- (void)handleTimer {
    [self sendData:[Screen takeScreenshotWithQuality:0.3] opcode:OPCODE_BINARY];
}

@end
