#include "Task.h"
#include "Touch.h"
#include "Process.h"
#include "AlertBox.h"
#include "SocketServer.h"
#include "Toast.h"
#include "DeviceInfo.h"
#import <mach/mach.h>
#include <Foundation/NSDistributedNotificationCenter.h>
#include "Screen.h"
#import "SysExecutor.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h> // 添加UIKit框架用于截图功能

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

// 新增截图函数
NSData* takeScreenshot() {
    @autoreleasepool {
        // 获取主屏幕
        UIScreen *mainScreen = [UIScreen mainScreen];
        // 获取屏幕的缩放因子
        CGFloat scale = mainScreen.scale;
        // 获取屏幕尺寸
        CGRect screenRect = mainScreen.bounds;
        
        // 创建图形上下文
        UIGraphicsBeginImageContextWithOptions(screenRect.size, NO, scale);
        CGContextRef context = UIGraphicsGetCurrentContext();
        
        // 遍历所有窗口
        for (UIWindow *window in [[UIApplication sharedApplication] windows]) {
            // 将窗口内容绘制到图形上下文中
            [window drawViewHierarchyInRect:window.bounds afterScreenUpdates:NO];
        }
        
        // 从图形上下文中获取图像
        UIImage *screenshot = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        // 将图像转换为JPEG格式的NSData
        NSData *imageData = UIImageJPEGRepresentation(screenshot, 0.8); // 80%质量
        
        return imageData;
    }
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
    else if(taskType == TASK_HOME){
        @autoreleasepool{
            pressHome();
        }
    }else if(taskType == TASK_SWITCH){
        @autoreleasepool{
            doublePressHome();
        }
    }
    else if(taskType == TASK_SCREENSHOT){ // 新增截图处理
        @autoreleasepool{
            NSData *screenshotData = takeScreenshot();
            if (screenshotData) {
                // 将截图数据转换为base64字符串返回
                NSString *base64String = [screenshotData base64EncodedStringWithOptions:0];
                notifyClient((UInt8*)[[NSString stringWithFormat:@"0;;%@\r\n", base64String] UTF8String], writeStreamRef);
            } else {
                notifyClient((UInt8*)"1;;Failed to take screenshot\r\n", writeStreamRef);
            }
        }
    }
}

void processHttpTask(HttpTask *task,CFWriteStreamRef writeStreamRef)
{
    int code = 200;
    NSString * res = @"success";
    if ([task.taskType isEqualToString:@"setClip"]) {
        // 得先让剪切板里有内容才能用 比如先找个东西复制一下 下面的获取剪切板内容也是
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        if (pasteboard.string){
            pasteboard.string = task.content;
        }else {
            code = 500;
            res = @"操作剪切板失败，请先随便找个东西复制一下";
        }
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
    }else if([task.taskType isEqualToString:@"deviceInfo"]){
        @autoreleasepool{
                NSError *err = nil;
                int intValue = [task.content intValue];
                res = getDeviceInfoFromRawData(intValue,  &err);
        }
    }else if([task.taskType isEqualToString:@"switchApp"]){
        @autoreleasepool{
            bringAppForeground(task.content);
        }
    }else if([task.taskType isEqualToString:@"pressHome"]){
        @autoreleasepool{
            pressHome();
        }
    }else if([task.taskType isEqualToString:@"doublePressHome"]){
        @autoreleasepool{
            doublePressHome();
        }
    }else if ([task.taskType isEqualToString:@"hideKeyboard"]) {
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"com.csmk.keyboardcontrol" object:NULL userInfo:@{@"task_id": @(2), @"task_content": @(1)} deliverImmediately: true];
    }else if ([task.taskType isEqualToString:@"input"]) {
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"com.csmk.keyboardcontrol" object:NULL userInfo:@{@"task_id": @(1), @"task_content": task.content} deliverImmediately: true];
    }else if ([task.taskType isEqualToString:@"del"]) {
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"com.csmk.keyboardcontrol" object:NULL userInfo:@{@"task_id": @(4), @"task_content": task.content} deliverImmediately: true];
    }else if([task.taskType isEqualToString:@"moveCursor"]){
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"com.csmk.keyboardcontrol" object:NULL userInfo:@{@"task_id": @(3), @"task_content": task.content} deliverImmediately: true];
    }else if([task.taskType isEqualToString:@"screenshot"]) { // 新增HTTP截图处理
        @autoreleasepool {
            NSData *screenshotData = takeScreenshot();
            if (screenshotData) {
                // 将截图数据转换为base64字符串返回
                res = [screenshotData base64EncodedStringWithOptions:0];
            } else {
                code = 500;
                res = @"Failed to take screenshot";
            }
        }
    }
    @autoreleasepool{
        sendHttpResponse(code, res, writeStreamRef);        
    }
}