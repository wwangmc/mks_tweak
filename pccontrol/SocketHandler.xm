#import "SocketHandler.h"
#import "WebServerSupport.h"
#import <Foundation/NSDistributedNotificationCenter.h>
#import "STHIDEventGenerator.h"
#include <limits.h>

@implementation SocketHandler

- (void)onData:(NSData *)data {
    [self sendData:data opcode:OPCODE_BINARY];
}

- (void)onText:(NSString *)text {
    [self handleTask:text];
}

- (void)onError:(NSError *)error {
    NSLog(@"Socket error: %@", error);
}

- (void)handleTask:(NSString *)text {
    NSError *error = nil;
    NSDictionary *body = MKSJSONDictionary([text dataUsingEncoding:NSUTF8StringEncoding], &error);
    if (!body) {
        [self sendText:@"反序列化失败"];
        return;
    }
    NSString *type = MKSString(body[@"type"]);
    if ([type isEqualToString:@"touch"]) {
        NSDictionary *touch = body[@"data"];
        if (!MKSIsValidTouch(touch)) {
            [self sendText:@"调用失败"];
            return;
        }
        CGPoint point = CGPointMake([touch[@"x"] doubleValue], [touch[@"y"] doubleValue]);
        NSString *action = touch[@"type"];
        dispatch_async(MKSInputQueue(), ^{
            STHIDEventGenerator *generator = [STHIDEventGenerator sharedGenerator];
            if ([action isEqualToString:@"up"]) [generator liftUp:point];
            else if ([action isEqualToString:@"tap"]) [generator tap:point];
            else [generator touchDown:point];
        });
    } else if ([type isEqualToString:@"home"]) {
        dispatch_async(MKSInputQueue(), ^{
            [[STHIDEventGenerator sharedGenerator] menuDoublePress];
        });
    } else if ([type isEqualToString:@"inputText"]) {
        NSString *value = MKSString(body[@"data"]);
        if (!value) {
            [self sendText:@"调用失败"];
            return;
        }
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"com.csmk.keyboardcontrol" object:nil
            userInfo:@{@"task_id": @(1), @"task_content": value} deliverImmediately:YES];
    } else if ([type isEqualToString:@"moveCursor"] || [type isEqualToString:@"backspace"]) {
        BOOL backspace = [type isEqualToString:@"backspace"];
        int count;
        if (!MKSReadInteger(body[@"data"], backspace ? 0 : INT_MIN, INT_MAX, &count)) {
            [self sendText:@"调用失败"];
            return;
        }
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"com.csmk.keyboardcontrol" object:nil
            userInfo:@{@"task_id": @(backspace ? 4 : 3), @"task_content": [NSString stringWithFormat:@"%d", count]}
            deliverImmediately:YES];
    } else {
        [self sendText:@"调用失败"];
    }
}

@end
