#include "Task.h"
#include "Touch.h"
#include "Process.h"
#include "AlertBox.h"
#include "SocketServer.h"
#include "Toast.h"
#include "UIKeyboard.h"
#include "DeviceInfo.h"
#include "TouchIndicator/TouchIndicatorWindow.h"
#import <mach/mach.h>
#include <Foundation/NSDistributedNotificationCenter.h>
#include "Screen.h"
#import "SysExecutor.h"
#import <Foundation/Foundation.h>

extern CFRunLoopRef recordRunLoop;

@implementation HttpTask

- (instancetype)initWithTaskType:(NSString *)taskType 
                         content:(NSString *)content
                     jsonContent:(NSDictionary *)jsonContent {
    self = [super init];
    if (self) {
        _taskType = taskType;
        _content = content;
        _jsonContent = jsonContent;
    }
    return self;
}

// 用于调试的描述方法
- (NSString *)description {
    return [NSString stringWithFormat:@"HttpTask { taskType: %@, content: %@ }", self.taskType, self.content];
}

@end

/*
get task type
*/
static int getTaskType(UInt8* dataArray)
{
	int taskType = 0;
	for (int i = 0; i <= 1; i++)
	{
		taskType += (dataArray[i] - '0')*pow(10, 1-i);
	}
	return taskType;
}
void sendGETRequest(NSString *urlString) {
    // 检查 URL 是否有效
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        NSLog(@"Invalid URL: %@", urlString);
        return;
    }

    // 创建请求
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"GET"];
    [request setTimeoutInterval:5]; // 设置超时时间为 10 秒

    // 创建 NSURLSession
    NSURLSession *session = [NSURLSession sharedSession];

    // 发起请求
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                            completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            NSLog(@"Request failed: %@ | URL: %@", error.localizedDescription, urlString);
            return;
        }

        // 请求成功，处理返回数据
        if (data) {
            NSString *responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSLog(@"Response from %@: %@", urlString, responseString);
        } else {
            NSLog(@"No data received from %@", urlString);
        }
    }];

    [task resume];
}
/**
Process Task
*/
void processTask(UInt8 *buff, CFWriteStreamRef writeStreamRef)
{
    //NSLog(@"### com.zjx.springboard: task type: %d. Data: %s", getTaskType(buff), buff);
    UInt8 *eventData = buff + 0x2;
    int taskType = getTaskType(buff);

    //for touching
    if (taskType == TASK_PERFORM_TOUCH)
    {
        @autoreleasepool{
            notifyClient(eventData, writeStreamRef); 
            performTouchFromRawData(eventData);
        }
    }
    else if (taskType == TASK_PROCESS_BRING_FOREGROUND) //bring to foreground
    {
        @autoreleasepool{   
            switchProcessForegroundFromRawData(eventData);
            notifyClient((UInt8*)"0\r\n", writeStreamRef); 
        }
    }
    else if (taskType == TASK_SHOW_ALERT_BOX)
    {
        @autoreleasepool{   
            NSError *err = nil;
            showAlertBoxFromRawData(eventData, &err);
            if (err)
            {
                notifyClient((UInt8*)[[err localizedDescription] UTF8String], writeStreamRef);
            }
            else
            {
                notifyClient((UInt8*)"0\r\n", writeStreamRef);
            }
        }
    }
    else if (taskType == TASK_RUN_SHELL)
    {
        @autoreleasepool{
            sysExecute([NSString stringWithFormat:@"\"%s\"", eventData]);
            notifyClient((UInt8*)"0\r\n", writeStreamRef);
        }
    }

    else if (taskType == TASK_SHOW_TOAST)
    {
        @autoreleasepool {
            NSError *err = nil;
            showToastFromRawData(eventData, &err);
            if (err)
            {
                notifyClient((UInt8*)[[err localizedDescription] UTF8String], writeStreamRef);
            }
            else
            {
                notifyClient((UInt8*)"0\r\n", writeStreamRef);
            }
        }
    }
    else if (taskType == TASK_TEXT_INPUT)
    {
        @autoreleasepool {
            NSError *err = nil;
            NSString *result = inputTextFromRawData(eventData,  &err);
            if (err)
            {
                notifyClient((UInt8*)[[err localizedDescription] UTF8String], writeStreamRef);
            }
            else
            {
                notifyClient((UInt8*)[[NSString stringWithFormat:@"0;;%@\r\n", result] UTF8String], writeStreamRef);
            }
        }
    }
    else if (taskType == TASK_GET_DEVICE_INFO)
    {
        @autoreleasepool {
            NSError *err = nil;
            NSString *deviceInfo = getDeviceInfoFromRawData(eventData,  &err);
            if (err)
            {
                notifyClient((UInt8*)[[err localizedDescription] UTF8String], writeStreamRef);
            }
            else
            {
                notifyClient((UInt8*)[[NSString stringWithFormat:@"0;;%@\r\n", deviceInfo] UTF8String], writeStreamRef);
            }
        }
    }
    else if (taskType == TASK_TOUCH_INDICATOR)
    {
        @autoreleasepool {
            NSError *err = nil;
            handleTouchIndicatorTaskWithRawData(eventData, &err);
            if (err)
            {
                notifyClient((UInt8*)[[err localizedDescription] UTF8String], writeStreamRef);
            }
            else
            {
                notifyClient((UInt8*)"0\r\n", writeStreamRef);
            }
        }
    }else if(taskType == TASK_HOME){
        sendGETRequest(@"http://localhost:50005/event?type=20&state=0&text=");
    }else if(taskType == TASK_SWITCH){
        sendGETRequest(@"http://localhost:50005/event?type=21&state=0&text=");
    }
}

void processHttpTask(HttpTask *task,CFWriteStreamRef writeStreamRef)
{
    int code = 200;
    NSString * res = @"success";
    if ([task.taskType isEqualToString:@"input"]) {
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"com.csmk.keyboardcontrol" object:NULL userInfo:@{@"task_id": @(1), @"task_content": task.content} deliverImmediately: true];
    } else if([task.taskType isEqualToString:@"getClip"]){
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        if (pasteboard.string){
            res = pasteboard.string;
        }else {
            code = 500;
            res = @"获取失败";
        }
    }else if([task.taskType isEqualToString:@"toast"]){
        @autoreleasepool {
            NSError *error = nil;
            showToastFromJson(task.jsonContent,&error);        
        }
    }else if([task.taskType isEqualToString:@"runShell"]){
        @autoreleasepool {
            res = runCommand(task.content);
        }
    }else if([task.taskType isEqualToString:@"sandboxPath"]){
        @autoreleasepool {
            res = getSandboxPathForBundleID(task.content);
        }
    }else if([task.taskType isEqualToString:@"touch"]){
        @autoreleasepool {
            NSError *error = nil;
            jsonToEventDataAndPerform(task.jsonContent, &error); 
            if (error) {
                code = 500;
                res = @"发生异常";
            }
        }
    }
    @autoreleasepool{
        sendHttpResponse(code, res, writeStreamRef);        
    }
}

