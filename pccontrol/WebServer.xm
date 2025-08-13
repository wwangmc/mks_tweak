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
#import <GCDWebServers/GCDWebServerDataResponse.h>
#import <GCDWebServers/GCDWebServerErrorResponse.h>
#import <GCDWebServers/GCDWebServerDataRequest.h>
#import <GCDWebServers/GCDWebServerStreamedResponse.h>
#import "Switcher.h"
#import "SocketHandler.h"
#import "DeviceConfigurator.h"
#import <GCDWebServers/GCDWebsocketServer.h>
#import <roothide.h>

static GCDWebsocketServer *webServer = nil;

NSDictionary* getJsonBody(GCDWebServerDataRequest *request,NSError *jsonError)
{
    return [NSJSONSerialization JSONObjectWithData:request.data
                                                        options:kNilOptions
                                                            error:&jsonError];
}
GCDWebServerDataResponse* dataResponse(NSDictionary *jsonData)
{
    GCDWebServerDataResponse *response = [GCDWebServerDataResponse responseWithJSONObject:jsonData];
    [response setValue:@"*" forAdditionalHeader:@"Access-Control-Allow-Origin"];       
    [response setValue:@"Content-Type" forAdditionalHeader:@"Access-Control-Allow-Headers"];   
    return response;
}
GCDWebServerDataResponse* staticSuccessResponse()
{
    NSDictionary *jsonData = @{
        @"status": @"success"
    };                      
    return dataResponse(jsonData);
}
GCDWebServerErrorResponse* missingParamResponse()
{
    GCDWebServerErrorResponse *response = [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_BadRequest
                                                        message:@"Missing parameter"];
    [response setValue:@"*" forAdditionalHeader:@"Access-Control-Allow-Origin"];       
    [response setValue:@"Content-Type" forAdditionalHeader:@"Access-Control-Allow-Headers"];
    return response;                                   
}
GCDWebServerErrorResponse* jsonFormatErrorResponse()
{
    GCDWebServerErrorResponse* response = [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_BadRequest
                                                            message:@"Invalid JSON"];
    [response setValue:@"*" forAdditionalHeader:@"Access-Control-Allow-Origin"];       
    [response setValue:@"Content-Type" forAdditionalHeader:@"Access-Control-Allow-Headers"];
    return response;   
}

void startWebServer()
{    
    // sudo killall -9 TSDaemon Hades 干掉触动
    if (webServer) {
        [webServer stop];
        webServer = nil;
    }
    webServer = [[GCDWebsocketServer alloc] init];
    initHandle(webServer);
    
    NSError *error = nil;
    // 使用同步启动方式确保启动完成
    BOOL success = [webServer startWithOptions:@{
        GCDWebServerOption_Port: @(WEB_PORT),
        GCDWebServerOption_BindToLocalhost: @NO,
        GCDWebServerOption_AutomaticallySuspendInBackground: @NO
    } error:&error];
    
    if (success) {
        NSLog(@"GCDWebServer running on %@", webServer.serverURL);
    } else {
        NSLog(@"Failed to start web server: %@", error);
    }
}
void initWebSocket(GCDWebsocketServer *webServer)
{
    [webServer addWebsocketHandlerForPath:@"/" withProcessBlock:^GCDWebsocketServerHandler * _Nullable(GCDWebsocketServerConnection * _Nonnull conn) {
        return [SocketHandler handlerWithConn:conn];
    }];
    [webServer addHandlerForMethod:@"GET" path:@"/" requestClass:[GCDWebServerRequest class] processBlock:^GCDWebServerResponse * _Nullable(__kindof GCDWebServerRequest * _Nonnull request) {
         NSURL *url = [NSURL URLWithString:@"index.html" relativeToURL:request.URL];
        
        return [GCDWebServerResponse responseWithRedirect:url permanent:NO];
    }];
}
void initToastHandle(GCDWebsocketServer *webServer)
{
    //悬浮窗
    [webServer addHandlerForMethod:@"POST"
                              path:@"/toast"
                      requestClass:[GCDWebServerDataRequest class] // 必须是 DataRequest 才能读取 Body
                      processBlock:^GCDWebServerResponse *(GCDWebServerDataRequest *request) {

                          NSError *jsonError;
                          NSDictionary *jsonBody = getJsonBody(request,jsonError);
                          if (jsonError) {
                              return jsonFormatErrorResponse();
                          }


                          NSError *error = nil;
                          showToastFromJson(jsonBody,&error);
                          if(error){
                              return [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_BadRequest
                                                                                message:@"发生异常"];
                          }
                          return staticSuccessResponse();
                      }];

    //隐藏悬浮窗
    [webServer addHandlerForMethod:@"GET"
                              path:@"/hideToast"
                      requestClass:[GCDWebServerDataRequest class] // 必须是 DataRequest 才能读取 Body
                      processBlock:^GCDWebServerResponse *(GCDWebServerDataRequest *request) {
                          [Toast hideToast];

                          return staticSuccessResponse();
                      }];
    // 巨魔悬浮窗
    [webServer addHandlerForMethod:@"POST"
                              path:@"/toast_V2"
                      requestClass:[GCDWebServerDataRequest class]
                      processBlock:^GCDWebServerResponse *(GCDWebServerDataRequest *request) {

                          NSError *jsonError;
                          NSDictionary *jsonBody = getJsonBody(request,jsonError);
                          if (jsonError) {
                              return jsonFormatErrorResponse();
                          }

                          NSString *text = jsonBody[@"text"];
                          NSString *color = jsonBody[@"color"];

                          if (!text || !color) {
                              return missingParamResponse();
                          }
                          [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"com.csmk.toast" object:NULL userInfo:@{@"text": text,@"color":color} deliverImmediately: true];

                          return staticSuccessResponse();
                      }];

    // 弹窗
    [webServer addHandlerForMethod:@"POST"
                              path:@"/alert"
                      requestClass:[GCDWebServerDataRequest class] // 必须是 DataRequest 才能读取 Body
                      processBlock:^GCDWebServerResponse *(GCDWebServerDataRequest *request) {

                          NSError *jsonError;
                          NSDictionary *jsonBody = getJsonBody(request,jsonError);
                          if (jsonError) {
                              return jsonFormatErrorResponse();
                          }

                          NSString *title = jsonBody[@"title"];
                          NSString *text = jsonBody[@"text"];
                          NSInteger time = [jsonBody[@"time"] integerValue];

                          if (!text||!title||!time) {
                              return missingParamResponse();
                          }

                          showAlertBox(title,text,time);
                          return staticSuccessResponse();
                      }];
}
void initAppHandle(GCDWebsocketServer *webServer)
{
    // 获取所有应用信息
    [webServer addHandlerForMethod:@"GET" path:@"/apps" requestClass:[GCDWebServerRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
        NSMutableArray *appsArray = getAllApplication();
        NSDictionary *jsonData = @{
                @"status": @"success",
                @"applications": appsArray
        };

        return dataResponse(jsonData);
    }];
    // 获取应用信息
    [webServer addHandlerForMethod:@"GET" path:@"/appInfo" requestClass:[GCDWebServerRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {

        NSString *pkgName = request.query[@"pkgName"];

        if (!pkgName) {
            return missingParamResponse();
        }
        NSDictionary *appInfo = getApplication(pkgName);
        NSDictionary *jsonData = @{
                @"status": @"success",
                @"info": appInfo
        };

        return dataResponse(jsonData);
    }];

    // 卸载应用
    [webServer addHandlerForMethod:@"GET" path:@"/uninstall" requestClass:[GCDWebServerRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {

        NSString *pkgName = request.query[@"pkgName"];

        if (!pkgName) {
            return missingParamResponse();
        }
        BOOL success = uninstall(pkgName);
        NSDictionary *jsonData = @{
                @"status": success?@"success":@"fail"
        };

        return dataResponse(jsonData);
    }];

    // 清理指定后台
    [webServer addHandlerForMethod:@"GET" path:@"/killByBID" requestClass:[GCDWebServerRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {

        NSString *pkgName = request.query[@"pkgName"];

        if (!pkgName) {
            return missingParamResponse();
        }
        killByBID(pkgName);

        return staticSuccessResponse();
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
                          return dataResponse(@{
                                  @"status": @"success",
                                  @"receivedItems": @(jsonArray.count)
                          });
                      }];

    // 切换应用
    [webServer addHandlerForMethod:@"GET"
                              path:@"/switchApp"
                      requestClass:[GCDWebServerRequest class]
                      processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {

                          NSString *pkgName = request.query[@"pkgName"];

                          if (!pkgName) {
                              return missingParamResponse();
                          }
                          bringAppForeground(pkgName);
                          return staticSuccessResponse();
                      }];
}

void initVpnHandle(GCDWebsocketServer *webServer)
{
    // 查看vpn状态
    [webServer addHandlerForMethod:@"GET" path:@"/vpnStatus" requestClass:[GCDWebServerRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
        BOOL isOpen = [DeviceConfigurator isVPNEnabled];
        NSDictionary *jsonData = @{
                @"status": @"success",
                @"data": isOpen?@"open":@"close"
        };
        return dataResponse(jsonData);
    }];

    // 开启vpn
    [webServer addHandlerForMethod:@"GET" path:@"/turnOnVPN" requestClass:[GCDWebServerRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
        [DeviceConfigurator turnOnVPN];
        return staticSuccessResponse();
    }];

    // 关闭vpn
    [webServer addHandlerForMethod:@"GET" path:@"/turnOffVPN" requestClass:[GCDWebServerRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
        [DeviceConfigurator turnOffVPN];
        return staticSuccessResponse();
    }];
}
void initSettingHandle(GCDWebsocketServer *webServer)
{
    // 获取当前时区
    [webServer addHandlerForMethod:@"GET" path:@"/currentTimeZone" requestClass:[GCDWebServerRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
        NSString * res = [DeviceConfigurator currentTimeZone];

        NSDictionary *jsonData = @{
                @"status": @"success",
                @"data": res
        };
        return dataResponse(jsonData);
    }];

    // 获取当前语言
    [webServer addHandlerForMethod:@"GET" path:@"/currentLanguage" requestClass:[GCDWebServerRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
        NSString * res = [DeviceConfigurator currentLanguage];

        NSDictionary *jsonData = @{
                @"status": @"success",
                @"data": res
        };
        return dataResponse(jsonData);
    }];

    // 当前地区
    [webServer addHandlerForMethod:@"GET" path:@"/currentLocale" requestClass:[GCDWebServerRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
        NSString * res = [DeviceConfigurator currentLocale];

        NSDictionary *jsonData = @{
                @"status": @"success",
                @"data": res
        };
        return dataResponse(jsonData);
    }];

    // 设置地区
    [webServer addHandlerForMethod:@"GET" path:@"/setLocale" requestClass:[GCDWebServerRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
        NSString *locale = request.query[@"locale"];
        if (!locale) {
            return missingParamResponse();
        }
        [DeviceConfigurator setCurrentLocale:locale];
        return staticSuccessResponse();
    }];

    // 设置语言
    [webServer addHandlerForMethod:@"GET" path:@"/setLanguage" requestClass:[GCDWebServerRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
        NSString *lang = request.query[@"lang"];
        if (!lang) {
            return missingParamResponse();
        }
        [DeviceConfigurator setCurrentLanguage:lang];
        return staticSuccessResponse();
    }];

    // 设置时区
    [webServer addHandlerForMethod:@"GET" path:@"/setCurrentTimeZone" requestClass:[GCDWebServerRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
        NSString *timeZone = request.query[@"timeZone"];
        if (!timeZone) {
            return missingParamResponse();
        }
        [DeviceConfigurator setCurrentTimeZone:timeZone];
        return staticSuccessResponse();
    }];

    [webServer addHandlerForMethod:@"GET" path:@"/setAllSetting" requestClass:[GCDWebServerRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
        NSString *timeZone = request.query[@"timeZone"];
        NSString *lang = request.query[@"lang"];
        NSString *locale = request.query[@"locale"];

        if (!timeZone&&!lang&&!locale) {
            return missingParamResponse();
        }
        [DeviceConfigurator setCurrentLocale:locale];
        [DeviceConfigurator setCurrentTimeZone:timeZone];
        [DeviceConfigurator setCurrentLanguage:lang];
        return staticSuccessResponse();
    }];
}
void initScreenHandle(GCDWebsocketServer *webServer)
{
    [webServer addHandlerForMethod:@"GET" path:@"/screenshot" requestClass:[GCDWebServerRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
        NSString *quality = request.query[@"quality"];
        if(!quality){
            return missingParamResponse();
        }
        float floatValue = [quality floatValue];

        NSData *imageData = [Screen takeScreenshotWithQuality_v2:floatValue];
        GCDWebServerDataResponse * response = [GCDWebServerDataResponse responseWithData:imageData contentType:@"image/jpeg"];
        [response setValue:@"*" forAdditionalHeader:@"Access-Control-Allow-Origin"];       
        [response setValue:@"Content-Type" forAdditionalHeader:@"Access-Control-Allow-Headers"];   
        return response;
    }];

    // 处理截图
    [webServer addHandlerForMethod:@"GET" path:@"/screenshot_v2" requestClass:[GCDWebServerRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
        NSString *quality = request.query[@"quality"];
        if(!quality){
            return missingParamResponse();
        }
        float floatValue = [quality floatValue];

        NSData *imageData = [Screen takeScreenshotWithQuality:floatValue];
        GCDWebServerDataResponse * response = [GCDWebServerDataResponse responseWithData:imageData contentType:@"image/jpeg"];
        [response setValue:@"*" forAdditionalHeader:@"Access-Control-Allow-Origin"];       
        [response setValue:@"Content-Type" forAdditionalHeader:@"Access-Control-Allow-Headers"];   
        return response;
    }];
    // 原图截图
    [webServer addHandlerForMethod:@"GET" path:@"/screenshot_original" requestClass:[GCDWebServerRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
  
        NSData *imageData = [Screen takeScreenshot];

        GCDWebServerDataResponse * response = [GCDWebServerDataResponse responseWithData:imageData contentType:@"image/jpeg"];
        [response setValue:@"*" forAdditionalHeader:@"Access-Control-Allow-Origin"];       
        [response setValue:@"Content-Type" forAdditionalHeader:@"Access-Control-Allow-Headers"];   
        return response;
    }];

    // 流式截图接口
    [webServer addHandlerForMethod:@"GET"
                              path:@"/screenshotStream"
                      requestClass:[GCDWebServerRequest class]
                      processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {

                          NSString *quality = request.query[@"quality"];
                          NSString *fpsStr = request.query[@"fps"];

                          if (!quality || !fpsStr) {
                              return missingParamResponse();
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

                                                      usleep(sleepTimeMicroseconds); // 控制帧率
                                                      return frame;
                                                  }
                                              }];

                          return response;
                      }];

}
void initHandle(GCDWebsocketServer *webServer)
{
    // 全局OPTIONS处理器
    [webServer addHandlerForMethod:@"OPTIONS"
                            pathRegex:@"^/"
                    requestClass:[GCDWebServerRequest class]
                    processBlock:^GCDWebServerResponse *(GCDWebServerRequest* request) {
        GCDWebServerResponse* response = [GCDWebServerResponse response];
        [response setValue:@"*" forAdditionalHeader:@"Access-Control-Allow-Origin"];
        [response setValue:@"*" forAdditionalHeader:@"Access-Control-Allow-Origin"];
        [response setValue:@"Content-Type" forAdditionalHeader:@"Access-Control-Allow-Headers"];
    
        [response setValue:@"43200" forAdditionalHeader:@"Access-Control-max-age"];
        return response;
    }];
    // 挂载自定义路径下的资源
    NSString* customPath = jbroot(@"/usr/lib/mks_dist");
    [webServer addGETHandlerForBasePath:@"/" 
                        directoryPath:customPath 
                        indexFilename:@"index.html"
                        cacheAge:3600
                        allowRangeRequests:YES];

    initScreenHandle(webServer);
    initWebSocket(webServer);

    [webServer addHandlerForMethod:@"GET" path:@"/GPT_PATH" requestClass:[GCDWebServerRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
        NSString *path = jbroot(@"/var/jb/var/mobile/gptdata/");
        NSDictionary *response = @{
                    @"status": @"success",
                    @"data": path
            };
        return dataResponse(response);
    }];

    // 虚拟定位
    [webServer addHandlerForMethod:@"GET" path:@"/setLocation" requestClass:[GCDWebServerRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
        NSString *latitude = request.query[@"Latitude"];
        NSString *longitude = request.query[@"Longitude"];

        if (!latitude || !longitude) {
            return missingParamResponse();
        }
        NSString *path = [jbroot(@"/var/mobile") stringByAppendingPathComponent:[@"com.csmk.locationfaker" stringByAppendingPathExtension:@"plist"]];
        
        NSDictionary *conf = @{@"Latitude": latitude,
                                    @"Longitude": longitude};
        [conf writeToFile:path atomically:YES];
        runCommand(@"killall -9 locationd");
        return staticSuccessResponse();
    }];

    // 按下home键
    [webServer addHandlerForMethod:@"GET" path:@"/pressHome" requestClass:[GCDWebServerRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
        pressHome();
        return staticSuccessResponse();
    }];
    // 双击home
    [webServer addHandlerForMethod:@"GET" path:@"/doublePressHome" requestClass:[GCDWebServerRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
        doublePressHome();
        return staticSuccessResponse();
    }];
    // 隐藏键盘
    [webServer addHandlerForMethod:@"GET" path:@"/hideKeyboard" requestClass:[GCDWebServerRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"com.csmk.keyboardcontrol" object:NULL userInfo:@{@"task_id": @(2), @"task_content": @(1)} deliverImmediately: true];

        // 返回 JSON 格式数据
        return staticSuccessResponse();
    }];
    // 输入文本
    [webServer addHandlerForMethod:@"POST"
                              path:@"/input"
                      requestClass:[GCDWebServerDataRequest class] // 必须是 DataRequest 才能读取 Body
                      processBlock:^GCDWebServerResponse *(GCDWebServerDataRequest *request) {

                          NSError *jsonError;
                          NSDictionary *jsonBody = getJsonBody(request,jsonError);
                          if (jsonError) {
                              return jsonFormatErrorResponse();
                          }

                          NSString *text = jsonBody[@"text"];

                          if (!text) {
                              return missingParamResponse();
                          }
                          [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"com.csmk.keyboardcontrol" object:NULL userInfo:@{@"task_id": @(1), @"task_content": text} deliverImmediately: true];

                          return staticSuccessResponse();
                      }];

    // 执行命令
    [webServer addHandlerForMethod:@"POST"
                              path:@"/runShell"
                      requestClass:[GCDWebServerDataRequest class] // 必须是 DataRequest 才能读取 Body
                      processBlock:^GCDWebServerResponse *(GCDWebServerDataRequest *request) {

                          NSError *jsonError;
                          NSDictionary *jsonBody = getJsonBody(request,jsonError);
                          if (jsonError) {
                              return jsonFormatErrorResponse();
                          }


                          NSString *cmd = jsonBody[@"cmd"];

                          if (!cmd) {
                              return missingParamResponse();
                          }
                          NSString *res = runCommand(cmd);
                          return dataResponse(@{
                                  @"status": @"success",
                                  @"data": res
                          });
                      }];

    // 删除文本
    [webServer addHandlerForMethod:@"GET"
                              path:@"/del"
                      requestClass:[GCDWebServerRequest class]
                      processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {

                          NSString *num = request.query[@"num"];

                          if (!num) {
                              return missingParamResponse();
                          }

                          [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"com.csmk.keyboardcontrol" object:NULL userInfo:@{@"task_id": @(4), @"task_content": num} deliverImmediately: true];

                          return staticSuccessResponse();
                      }];

    // 移动光标
    [webServer addHandlerForMethod:@"GET"
                              path:@"/moveCursor"
                      requestClass:[GCDWebServerRequest class]
                      processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {

                          NSString *num = request.query[@"num"];

                          if (!num) {
                              return missingParamResponse();
                          }

                          [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"com.csmk.keyboardcontrol" object:NULL userInfo:@{@"task_id": @(3), @"task_content": num} deliverImmediately: true];

                          return staticSuccessResponse();
                      }];


    //点击某个坐标
    [webServer addHandlerForMethod:@"POST"
                              path:@"/touch"
                      requestClass:[GCDWebServerDataRequest class] // 必须是 DataRequest 才能读取 Body
                      processBlock:^GCDWebServerResponse *(GCDWebServerDataRequest *request) {

                          NSError *jsonError;
                          NSDictionary *jsonBody = getJsonBody(request,jsonError);
                          if (jsonError) {
                              return jsonFormatErrorResponse();
                          }

                          NSError *error = nil;
                          jsonToEventDataAndPerform(jsonBody, &error);
                          if (error) {
                              return [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_BadRequest
                                                                                message:@"点击异常"];
                          }

                          return staticSuccessResponse();
                      }];

    //获取设备信息
    [webServer addHandlerForMethod:@"GET"
                              path:@"/deviceInfo"
                      requestClass:[GCDWebServerRequest class]
                      processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {

                          NSString *type = request.query[@"type"];

                          if (!type) {
                              return missingParamResponse();
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

                          return dataResponse(response);
                      }];


    // 设置剪切板内容
    [webServer addHandlerForMethod:@"POST"
                              path:@"/setClip"
                      requestClass:[GCDWebServerDataRequest class] // 必须是 DataRequest 才能读取 Body
                      processBlock:^GCDWebServerResponse *(GCDWebServerDataRequest *request) {

                          NSError *jsonError;
                          NSDictionary *jsonBody = getJsonBody(request,jsonError);
                          if (jsonError) {
                              return jsonFormatErrorResponse();
                          }


                          NSString *text = jsonBody[@"text"];

                          if (!text) {
                              return missingParamResponse();
                          }
                          UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
                          if (pasteboard.string){
                              pasteboard.string = text;
                          }else {
                              return [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_BadRequest
                                                                                message:@"操作剪切板失败，请先随便找个东西复制一下"];
                          }
                          return staticSuccessResponse();
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
        return dataResponse(jsonData);
    }];

    //当前应用
    [webServer addHandlerForMethod:@"GET" path:@"/currApp" requestClass:[GCDWebServerRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
        // NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];//获取app版本信息
        // NSString *app_Name = [infoDictionary objectForKey:@"CFBundleDisplayName"];
        id app_Name = getFrontMostApplication();
        NSDictionary *jsonData = @{
                @"status": @"success",
                @"data": app_Name,
        };
        // 返回 JSON 格式数据
        return dataResponse(jsonData);
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

                          return dataResponse(response);
                      }];

    // 输入当前苹果账号的密码
    [webServer addHandlerForMethod:@"GET"
                              path:@"/inputPwd"
                      requestClass:[GCDWebServerRequest class]
                      processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {

                          currPwd();

                          return staticSuccessResponse();
                      }];


    //重启用户空间
    [webServer addHandlerForMethod:@"GET" path:@"/rebootUserspace" requestClass:[GCDWebServerRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
        rebootUserspace();
        return staticSuccessResponse();
    }];

    initAppHandle(webServer);

    initToastHandle(webServer);

    initVpnHandle(webServer);

    initSettingHandle(webServer);

}
