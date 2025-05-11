#include "WebServer.h"
#include "Screen.h"
#include "Touch.h"
#include <Foundation/NSDistributedNotificationCenter.h>
#import "SysExecutor.h"
#include "Process.h"
#include "AlertBox.h"
#include "Toast.h"
#include "DeviceInfo.h"
#import "GCDWebServerDataResponse.h"
#import "GCDWebServerErrorResponse.h"
#import "GCDWebServerDataRequest.h"
#import "GCDWebServerStreamedResponse.h"

void startWebServer()
{
    GCDWebServer *webServer = [[GCDWebServer alloc] init];
    initHandle(webServer);    
    [webServer startWithPort:WEB_PORT bonjourName:nil];
    NSLog(@"GCDWebServer running on %@", webServer.serverURL);
}

void initHandle(GCDWebServer *webServer)
{
    // 处理截图
    [webServer addHandlerForMethod:@"GET" path:@"/screenshot" requestClass:[GCDWebServerRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
        NSData *imageData = [Screen takeScreenshotWithQuality:0.3];

        return [GCDWebServerDataResponse responseWithData:imageData contentType:@"image/jpeg"];
    }];

    // 流式截图接口
     [webServer addHandlerForMethod:@"GET"
                             path:@"/live_screenshot"
                     requestClass:[GCDWebServerRequest class]
                     processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
        Screen *screen = [Screen new];

        GCDWebServerStreamedResponse *response = 
            [GCDWebServerStreamedResponse responseWithContentType:@"multipart/x-mixed-replace; boundary=boundary"
                                               asyncStreamBlock:^(GCDWebServerBodyReaderCompletionBlock completionBlock) {

            screen.isStreaming = YES;
            screen.streamCompletionBlock = completionBlock;
            
            screen.displayLink = [CADisplayLink displayLinkWithTarget:screen selector:@selector(captureFrame:)];
            [screen.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
            screen.displayLink.preferredFramesPerSecond = 20; // 10 FPS
        }];
        
        // 客户端断开时停止流
        /*response.connectionDidCloseBlock  = ^{
            [screen stopStreaming];
        };*/
        
        return response;
    }];

    // 按下home键
    [webServer addHandlerForMethod:@"GET" path:@"/pressHome" requestClass:[GCDWebServerRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
            pressHome();
            NSDictionary *jsonData = @{
                @"status": @"success",
                @"data": @"操作成功",
            /*@"device": @{
                @"name": [[UIDevice currentDevice] name],
                @"system": [[UIDevice currentDevice] systemVersion]
            }*/
            };
        
        // 返回 JSON 格式数据
        return [GCDWebServerDataResponse responseWithJSONObject:jsonData];
    }];
    // 双击home
    [webServer addHandlerForMethod:@"GET" path:@"/doublePressHome" requestClass:[GCDWebServerRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
            doublePressHome();
            NSDictionary *jsonData = @{
                @"status": @"success",
                @"data": @"操作成功"
            };
        
        // 返回 JSON 格式数据
        return [GCDWebServerDataResponse responseWithJSONObject:jsonData];
    }];
    // 隐藏键盘
    [webServer addHandlerForMethod:@"GET" path:@"/hideKeyboard" requestClass:[GCDWebServerRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"com.csmk.keyboardcontrol" object:NULL userInfo:@{@"task_id": @(2), @"task_content": @(1)} deliverImmediately: true];
        NSDictionary *jsonData = @{
            @"status": @"success",
            @"data": @"操作成功"
        };
        
        // 返回 JSON 格式数据
        return [GCDWebServerDataResponse responseWithJSONObject:jsonData];
    }];
    // 输入文本
    [webServer addHandlerForMethod:@"POST"
                         path:@"/input"
                 requestClass:[GCDWebServerDataRequest class] // 必须是 DataRequest 才能读取 Body
                 processBlock:^GCDWebServerResponse *(GCDWebServerDataRequest *request) {
    
        NSError *jsonError;
        NSDictionary *jsonBody = [NSJSONSerialization JSONObjectWithData:request.data
                                                            options:kNilOptions
                                                                error:&jsonError];
        
        if (jsonError) {
            return [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_BadRequest
                                                            message:@"Invalid JSON"];
        }
        
        NSString *text = jsonBody[@"text"];
        
        if (!text) {
            return [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_BadRequest
                                                            message:@"Missing text"];
        }
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"com.csmk.keyboardcontrol" object:NULL userInfo:@{@"task_id": @(1), @"task_content": text} deliverImmediately: true];

        return [GCDWebServerDataResponse responseWithJSONObject:@{
            @"status": @"success",
            @"data": @"操作成功"
        }];
    }];

    // 执行命令
    [webServer addHandlerForMethod:@"POST"
                         path:@"/runShell"
                 requestClass:[GCDWebServerDataRequest class] // 必须是 DataRequest 才能读取 Body
                 processBlock:^GCDWebServerResponse *(GCDWebServerDataRequest *request) {
    
        NSError *jsonError;
        NSDictionary *jsonBody = [NSJSONSerialization JSONObjectWithData:request.data
                                                            options:kNilOptions
                                                                error:&jsonError];
        
        if (jsonError) {
            return [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_BadRequest
                                                            message:@"Invalid JSON"];
        }
        
        NSString *cmd = jsonBody[@"cmd"];
        
        if (!cmd) {
            return [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_BadRequest
                                                            message:@"Missing cmd"];
        }
        NSString *res = runCommand(cmd);
        return [GCDWebServerDataResponse responseWithJSONObject:@{
            @"status": @"success",
            @"data": res
        }];
    }];
    
    // 删除文本
    [webServer addHandlerForMethod:@"GET"
                         path:@"/del"
                 requestClass:[GCDWebServerRequest class]
                 processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
    
        NSString *num = request.query[@"num"];
        
        if (!num) {
            return [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_BadRequest
                                                        message:@"Missing 'num' parameter"];
        }
        
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"com.csmk.keyboardcontrol" object:NULL userInfo:@{@"task_id": @(4), @"task_content": num} deliverImmediately: true];

        NSDictionary *response = @{
            @"status": @"success",
            @"data": @"操作成功"
        };
        
        return [GCDWebServerDataResponse responseWithJSONObject:response];
    }];

    // 移动光标
    [webServer addHandlerForMethod:@"GET"
                         path:@"/moveCursor"
                 requestClass:[GCDWebServerRequest class]
                 processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
    
        NSString *num = request.query[@"num"];
        
        if (!num) {
            return [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_BadRequest
                                                        message:@"Missing 'num' parameter"];
        }
        
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"com.csmk.keyboardcontrol" object:NULL userInfo:@{@"task_id": @(3), @"task_content": num} deliverImmediately: true];

        NSDictionary *response = @{
            @"status": @"success",
            @"data": @"操作成功"
        };
        
        return [GCDWebServerDataResponse responseWithJSONObject:response];
    }];

    // 切换应用
    [webServer addHandlerForMethod:@"GET"
                         path:@"/switchApp"
                 requestClass:[GCDWebServerRequest class]
                 processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
    
        NSString *pkgName = request.query[@"pkgName"];
        
        if (!pkgName) {
            return [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_BadRequest
                                                        message:@"Missing 'pkgName' parameter"];
        }
        bringAppForeground(pkgName);
        NSDictionary *response = @{
            @"status": @"success",
            @"data": @"操作成功"
        };
        
        return [GCDWebServerDataResponse responseWithJSONObject:response];
    }];

    //点击某个坐标
    [webServer addHandlerForMethod:@"POST"
                         path:@"/touch"
                 requestClass:[GCDWebServerDataRequest class] // 必须是 DataRequest 才能读取 Body
                 processBlock:^GCDWebServerResponse *(GCDWebServerDataRequest *request) {
    
        NSError *jsonError;
        NSDictionary *jsonBody = [NSJSONSerialization JSONObjectWithData:request.data
                                                            options:kNilOptions
                                                                error:&jsonError];
        
        if (jsonError) {
            return [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_BadRequest
                                                            message:@"Invalid JSON"];
        }
        
        NSError *error = nil;
        jsonToEventDataAndPerform(jsonBody, &error); 
        
        if (error) {
            return [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_BadRequest
                                                            message:@"点击异常"];
        }

        return [GCDWebServerDataResponse responseWithJSONObject:@{
            @"status": @"success",
            @"data": @"操作成功"
        }];
    }];

    //获取设备信息
    [webServer addHandlerForMethod:@"GET"
                         path:@"/deviceInfo"
                 requestClass:[GCDWebServerRequest class]
                 processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
    
        NSString *type = request.query[@"type"];
        
        if (!type) {
            return [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_BadRequest
                                                        message:@"Missing 'type' parameter"];
        }
        NSError *err = nil;
        int intValue = [type intValue];
        NSString *res = getDeviceInfoFromRawData(intValue,  &err);
        if(err){
             return [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_BadRequest
                                                        message:@"发生异常"];
        }
        NSDictionary *response = @{
            @"status": @"success",
            @"data": res
        };
        
        return [GCDWebServerDataResponse responseWithJSONObject:response];
    }];

    //悬浮窗
    [webServer addHandlerForMethod:@"POST"
                         path:@"/toast"
                 requestClass:[GCDWebServerDataRequest class] // 必须是 DataRequest 才能读取 Body
                 processBlock:^GCDWebServerResponse *(GCDWebServerDataRequest *request) {
    
        NSError *jsonError;
        NSDictionary *jsonBody = [NSJSONSerialization JSONObjectWithData:request.data
                                                            options:kNilOptions
                                                                error:&jsonError];
        
        if (jsonError) {
            return [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_BadRequest
                                                            message:@"Invalid JSON"];
        }
        
        NSError *error = nil;
        showToastFromJson(jsonBody,&error);        
        if(error){
            return [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_BadRequest
                                                message:@"发生异常"];
        }
        return [GCDWebServerDataResponse responseWithJSONObject:@{
            @"status": @"success",
            @"data": @"操作成功"
        }];
    }];

    // 弹窗
    [webServer addHandlerForMethod:@"POST"
                         path:@"/alert"
                 requestClass:[GCDWebServerDataRequest class] // 必须是 DataRequest 才能读取 Body
                 processBlock:^GCDWebServerResponse *(GCDWebServerDataRequest *request) {
    
        NSError *jsonError;
        NSDictionary *jsonBody = [NSJSONSerialization JSONObjectWithData:request.data
                                                            options:kNilOptions
                                                                error:&jsonError];
        
        if (jsonError) {
            return [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_BadRequest
                                                            message:@"Invalid JSON"];
        }
        NSString *title = jsonBody[@"title"];
        NSString *text = jsonBody[@"text"];
        NSInteger time = [jsonBody[@"time"] integerValue];

        if (!text||!title||!time) {
            return [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_BadRequest
                                                            message:@"Missing text/title/time"];
        }
        
        showAlertBox(title,text,time);        
        return [GCDWebServerDataResponse responseWithJSONObject:@{
            @"status": @"success",
            @"data": @"操作成功"
        }];
    }];
    
    // 设置剪切板内容
    [webServer addHandlerForMethod:@"POST"
                         path:@"/setClip"
                 requestClass:[GCDWebServerDataRequest class] // 必须是 DataRequest 才能读取 Body
                 processBlock:^GCDWebServerResponse *(GCDWebServerDataRequest *request) {
    
        NSError *jsonError;
        NSDictionary *jsonBody = [NSJSONSerialization JSONObjectWithData:request.data
                                                            options:kNilOptions
                                                                error:&jsonError];
        
        if (jsonError) {
            return [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_BadRequest
                                                            message:@"Invalid JSON"];
        }
        
        NSString *text = jsonBody[@"text"];
        
        if (!text) {
            return [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_BadRequest
                                                            message:@"Missing text"];
        }
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        if (pasteboard.string){
            pasteboard.string = text;
        }else {
            return [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_BadRequest
                                                message:@"操作剪切板失败，请先随便找个东西复制一下"];
        }
        return [GCDWebServerDataResponse responseWithJSONObject:@{
            @"status": @"success",
            @"data": @"操作成功"
        }];
    }];

    //获取剪切板内容
    [webServer addHandlerForMethod:@"GET" path:@"/getClip" requestClass:[GCDWebServerRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        NSString *res;
        if (pasteboard.string){
            res = pasteboard.string;
        }else {
            res = @"获取失败";
        }
        NSDictionary *jsonData = @{
            @"status": @"success",
            @"data": res,
        };
        // 返回 JSON 格式数据
        return [GCDWebServerDataResponse responseWithJSONObject:jsonData];
    }];

    // 获取应用沙盒目录
    [webServer addHandlerForMethod:@"GET"
                         path:@"/sandboxPath"
                 requestClass:[GCDWebServerRequest class]
                 processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
    
        NSString *pkgName = request.query[@"pkgName"];
        
        if (!pkgName) {
            return [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_BadRequest
                                                        message:@"Missing 'pkgName' parameter"];
        }
        NSString *res = getSandboxPathForBundleID(pkgName);
        NSDictionary *response = @{
            @"status": @"success",
            @"data": res
        };
        
        return [GCDWebServerDataResponse responseWithJSONObject:response];
    }];
}