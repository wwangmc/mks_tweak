#import "SocketHandler.h"
#import <Foundation/NSDistributedNotificationCenter.h>
#import "Process.h"
#import "Request.h"
#import "Screen.h"
#import "Touch.h"
static NSTimer *_globalTimer;
@interface SocketHandler ()
@end

@implementation SocketHandler

-(void)onData:(NSData *)data{
    [self sendData:data opcode:OPCODE_BINARY];
}

-(void)onText:(NSString *)text{
    [self handleTask:text];
}

-(void)onClosed{
    // [self stopTimer];

}
-(void)onError:(NSError*)error{
    // 输出异常信息后 和close走一样逻辑
    NSLog(@"Socket error: %@", error);
    // [self stopTimer];
}
-(void)onConnected{
    // [self startTimer];
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
- (NSDictionary *)formatJSON:(NSString *)text error:(NSError **)error {
    // NSString *nestedJsonString = @"{\"user\":{\"name\":\"Alice\",\"preferences\":[\"reading\",\"hiking\"]}}";
    NSData *nestedJsonData = [text dataUsingEncoding:NSUTF8StringEncoding];

    id nestedJsonObject = [NSJSONSerialization JSONObjectWithData:nestedJsonData 
                                                        options:kNilOptions 
                                                        error:error];

    if ([nestedJsonObject isKindOfClass:[NSDictionary class]]) {
        return nestedJsonObject;
    }
    return nil;

}
- (void)handleTask:(NSString *)text {
    NSError *error = nil;

    NSDictionary* data_dict = [self formatJSON:text error:&error];
    if(error){
        [self sendText:@"反序列化失败"];
    }                                                       
    if([data_dict[@"type"] isEqualToString:@"touch"]){
        NSDictionary *data = data_dict[@"data"];
        // [self sendText:data_dict[@"data"]];
        jsonToEventDataAndPerform(data,&error);
        if(error){
            [self sendText:@"调用失败"];
        }
    }
}
@end
