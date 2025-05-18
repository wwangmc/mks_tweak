#import "WebServer.h"
#import "Screen.h"
#import "Touch.h"
#import <Foundation/NSDistributedNotificationCenter.h>
#import "SysExecutor.h"
#import "Process.h"
#import "AlertBox.h"
#import "Toast.h"
#import "DeviceInfo.h"
#import "AppStore.h"
#import "Application.h"
#import "GCDWebServerDataResponse.h"
#import "GCDWebServerErrorResponse.h"
#import "GCDWebServerDataRequest.h"
#import "GCDWebServerStreamedResponse.h"
#import "Switcher.h"

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
        NSString *quality = request.query[@"quality"];
        if(!quality){
            return [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_BadRequest
                                                message:@"Missing quality"];
        }
        float floatValue = [quality floatValue];

        NSData *imageData = [Screen takeScreenshotWithQuality:floatValue];

        return [GCDWebServerDataResponse responseWithData:imageData contentType:@"image/jpeg"];
    }];

    // 流式截图接口
    [webServer addHandlerForMethod:@"GET"
                            path:@"/screenshotStream"
                    requestClass:[GCDWebServerRequest class]
                    processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
        
        NSString *quality = request.query[@"quality"];
        NSString *fpsStr = request.query[@"fps"];
        
        if (!quality || !fpsStr) {
            return [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_BadRequest
                                                            message:@"Missing quality or fps"];
        }
        
        float floatValue = [quality floatValue];
        int fps = [fpsStr intValue];
        if (fps <= 0 || fps > 60) fps = 10; // 安全兜底，限制范围
        
        int sleepTimeMicroseconds = 1000000 / fps; // 帧间隔时间 usleep 用微秒
        
        GCDWebServerStreamedResponse* response = [GCDWebServerStreamedResponse
            responseWithContentType:@"multipart/x-mixed-replace; boundary=--frame"
                        streamBlock:^NSData* (NSError** error) {
            
            @autoreleasepool {
                NSData* imageData = [Screen takeScreenshotWithQuality:floatValue];
                if (!imageData) {
                    if (error) *error = [NSError errorWithDomain:@"screenshot" code:500 userInfo:nil];
                    return nil;
                }

                NSMutableData* frame = [NSMutableData data];
                [frame appendData:[@"--frame\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
                [frame appendData:[@"Content-Type: image/jpeg\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
                NSString* header = [NSString stringWithFormat:@"Content-Length: %lu\r\n\r\n", (unsigned long)imageData.length];
                [frame appendData:[header dataUsingEncoding:NSUTF8StringEncoding]];
                [frame appendData:imageData];
                [frame appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];

                usleep(sleepTimeMicroseconds); // ⏱ 控制帧率
                return frame;
            }
        }];
        
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

    // 获取所有登录过的苹果账号
    [webServer addHandlerForMethod:@"GET"
                         path:@"/accounts"
                 requestClass:[GCDWebServerRequest class]
                 processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
    
        NSArray *accounts = getAllAccount();
        NSMutableArray *accountInfos = [NSMutableArray array];
        
        for (SSAccount *account in accounts) {
            NSDictionary *accountInfo = @{
                @"isActive": @([account isActive]),
                @"isLocalAccount": @([account isLocalAccount]),
                @"firstName": [account firstName] ?: @"",
                @"lastName": [account lastName] ?: @"",
                @"accountName": [account accountName] ?: @"",
                @"storeFrontIdentifier": [account storeFrontIdentifier] ?: @""
            };
            [accountInfos addObject:accountInfo];
        }
        NSDictionary *response = @{
            @"status": @"success",
            @"data": accountInfos
        };
        
        return [GCDWebServerDataResponse responseWithJSONObject:response];
    }];

    // 输入当前苹果账号的密码
    [webServer addHandlerForMethod:@"GET"
                        path:@"/inputPwd"
                requestClass:[GCDWebServerRequest class]
                processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
    
        currPwd();

        NSDictionary *response = @{
            @"status": @"success",
            @"data": @""
        };
        
        return [GCDWebServerDataResponse responseWithJSONObject:response];
    }];

    // 获取所有应用信息
    [webServer addHandlerForMethod:@"GET" path:@"/apps" requestClass:[GCDWebServerRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
        NSMutableArray *appsArray = getAllApplication();
        NSDictionary *jsonData = @{
            @"status": @"success",
            @"applications": appsArray
        };
        
        return [GCDWebServerDataResponse responseWithJSONObject:jsonData];
    }];
    // 获取应用信息
    [webServer addHandlerForMethod:@"GET" path:@"/appInfo" requestClass:[GCDWebServerRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
            
        NSString *pkgName = request.query[@"pkgName"];
        
        if (!pkgName) {
            return [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_BadRequest
                                                        message:@"Missing 'pkgName' parameter"];
        }
        NSDictionary *appInfo = getApplication(pkgName);
        NSDictionary *jsonData = @{
            @"status": @"success",
            @"info": appInfo
        };
        
        return [GCDWebServerDataResponse responseWithJSONObject:jsonData];
    }];

    // 卸载应用
    [webServer addHandlerForMethod:@"GET" path:@"/uninstall" requestClass:[GCDWebServerRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
            
        NSString *pkgName = request.query[@"pkgName"];
        
        if (!pkgName) {
            return [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_BadRequest
                                                        message:@"Missing 'pkgName' parameter"];
        }
        BOOL success = uninstall(pkgName);
        NSDictionary *jsonData = @{
            @"status": success?@"success":@"fail"
        };
        
        return [GCDWebServerDataResponse responseWithJSONObject:jsonData];
    }];

    // 清理指定后台
    [webServer addHandlerForMethod:@"GET" path:@"/killByBID" requestClass:[GCDWebServerRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
            
        NSString *pkgName = request.query[@"pkgName"];
        
        if (!pkgName) {
            return [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_BadRequest
                                                        message:@"Missing 'pkgName' parameter"];
        }
        killByBID(pkgName);
        NSDictionary *jsonData = @{
            @"status": @"success"
        };
        
        return [GCDWebServerDataResponse responseWithJSONObject:jsonData];
    }];

    // 清理所有后台
    [webServer addHandlerForMethod:@"POST"
                         path:@"/killAll"
                 requestClass:[GCDWebServerDataRequest class] // 必须是 DataRequest 才能读取 Body
                 processBlock:^GCDWebServerResponse *(GCDWebServerDataRequest *request){
    
        GCDWebServerDataRequest *dataRequest = (GCDWebServerDataRequest *)request;
        
        NSError *jsonError;
        id jsonObject = [NSJSONSerialization JSONObjectWithData:dataRequest.data
                                                    options:kNilOptions
                                                        error:&jsonError];
        NSArray *jsonArray = @[];
        if (!jsonError && [jsonObject isKindOfClass:[NSArray class]]) {
            jsonArray = (NSArray *)jsonObject;
            NSLog(@"Received JSON Array: %@", jsonArray);
        }
        
        killAll(jsonArray);
        
        // 返回成功响应
        return [GCDWebServerDataResponse responseWithJSONObject:@{
            @"status": @"success",
            @"receivedItems": @(jsonArray.count)
        }];
    }];
}