#import "WebServer.h"
#import "WebServerSupport.h"
#import "ScreenshotStream.h"
#import "Screen.h"
#import <Foundation/NSDistributedNotificationCenter.h>
#import "SysExecutor.h"
#import "Process.h"
#import "AlertBox.h"
#import "Toast.h"
#import "DeviceInfo.h"
#import "AppStore.h"
#import "Application.h"
#import "Switcher.h"
#import "SocketHandler.h"
#import "DeviceConfigurator.h"
#import <roothide.h>
#import "STHIDEventGenerator.h"
#import "ADTCC.h"
#import <MobileCoreServices/LSApplicationProxy.h>
#include <limits.h>
#include <float.h>

static GCDWebsocketServer *webServer = nil;

static void addGETHandler(GCDWebsocketServer *server, NSString *path, GCDWebServerProcessBlock handler) {
    [server addHandlerForMethod:@"GET" path:path requestClass:[GCDWebServerRequest class] processBlock:handler];
}

static GCDWebServerResponse *imageResponse(NSData *image, NSString *contentType) {
    if (!image.length) return MKSServerError(@"Failed to capture screen");
    GCDWebServerDataResponse *response = [GCDWebServerDataResponse responseWithData:image contentType:contentType];
    [response setValue:@"no-store" forAdditionalHeader:@"Cache-Control"];
    return MKSApplyCORS(response);
}

void startWebServer(void) {
    // Initialize UIKit-dependent screen metrics on the main thread, then serialize HID work off it.
    MKSOnMainThread(^{ [STHIDEventGenerator sharedGenerator]; });
    // Repeated initialization must not disconnect active HTTP / WebSocket clients.
    @synchronized ([GCDWebsocketServer class]) {
        if (webServer.isRunning) return;
        GCDWebsocketServer *server = [[GCDWebsocketServer alloc] init];
        initHandle(server);
        NSError *error = nil;
        if ([server startWithOptions:@{
            GCDWebServerOption_Port: @(WEB_PORT),
            GCDWebServerOption_BindToLocalhost: @NO,
            GCDWebServerOption_AutomaticallySuspendInBackground: @NO
        } error:&error]) {
            webServer = server;
            NSLog(@"GCDWebServer running on %@", server.serverURL);
        } else {
            webServer = nil;
            NSLog(@"Failed to start web server: %@", error);
        }
    }
}

static void initWebSocket(GCDWebsocketServer *server) {
    [server addWebsocketHandlerForPath:@"/" withProcessBlock:^GCDWebsocketServerHandler *(GCDWebsocketServerConnection *conn) {
        return [SocketHandler handlerWithConn:conn];
    }];
    addGETHandler(server, @"/", ^GCDWebServerResponse *(GCDWebServerRequest *request) {
        NSURL *url = [NSURL URLWithString:@"index.html" relativeToURL:request.URL];
        return MKSApplyCORS([GCDWebServerResponse responseWithRedirect:url permanent:NO]);
    });
}

static void initToastHandle(GCDWebsocketServer *server) {
    MKSAddJSONHandler(server, @"/toast", ^GCDWebServerResponse *(NSDictionary *body) {
        NSString *type = MKSString(body[@"type"]);
        if (!type || !MKSString(body[@"content"]) ||
            !MKSReadNumber(body[@"duration"], 0, INT_MAX, NULL) ||
            (body[@"position"] && !MKSString(body[@"position"])) ||
            (body[@"fontSize"] && !MKSReadInteger(body[@"fontSize"], 1, INT_MAX, NULL))) {
            return missingParamResponse();
        }
        if (![@[@"hide", @"error", @"warning", @"message", @"success"] containsObject:type]) {
            return MKSClientError(@"Invalid toast type");
        }
        NSError *error = nil;
        showToastFromJson(body, &error);
        return error ? MKSClientError(error.localizedDescription) : staticSuccessResponse();
    });
    addGETHandler(server, @"/hideToast", ^GCDWebServerResponse *(GCDWebServerRequest *request) {
        [Toast hideToast];
        return staticSuccessResponse();
    });
    MKSAddJSONHandler(server, @"/toast_V2", ^GCDWebServerResponse *(NSDictionary *body) {
        NSString *text = MKSString(body[@"text"]);
        NSString *color = MKSString(body[@"color"]);
        if (!text || !color.length) return missingParamResponse();
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"com.csmk.toast" object:nil
            userInfo:@{@"text": text, @"color": color} deliverImmediately:YES];
        return staticSuccessResponse();
    });
    MKSAddJSONHandler(server, @"/alert", ^GCDWebServerResponse *(NSDictionary *body) {
        NSString *title = MKSString(body[@"title"]);
        NSString *text = MKSString(body[@"text"]);
        double duration;
        if (!title || !text || !MKSReadNumber(body[@"time"], DBL_MIN, INT_MAX, &duration)) {
            return missingParamResponse();
        }
        showAlertBox(title, text, duration);
        return staticSuccessResponse();
    });
}

static void initAppHandle(GCDWebsocketServer *server) {
    addGETHandler(server, @"/apps", ^GCDWebServerResponse *(GCDWebServerRequest *request) {
        return dataResponse(@{@"status": @"success", @"applications": getAllApplication() ?: @[]});
    });
    addGETHandler(server, @"/appInfo", ^GCDWebServerResponse *(GCDWebServerRequest *request) {
        NSString *pkgName = MKSString(request.query[@"pkgName"]);
        if (!pkgName.length) return missingParamResponse();
        return dataResponse(@{@"status": @"success", @"info": getApplication(pkgName) ?: @{}});
    });
    addGETHandler(server, @"/uninstall", ^GCDWebServerResponse *(GCDWebServerRequest *request) {
        NSString *pkgName = MKSString(request.query[@"pkgName"]);
        if (!pkgName.length) return missingParamResponse();
        return dataResponse(@{@"status": uninstall(pkgName) ? @"success" : @"fail"});
    });
    addGETHandler(server, @"/killByBID", ^GCDWebServerResponse *(GCDWebServerRequest *request) {
        NSString *pkgName = MKSString(request.query[@"pkgName"]);
        if (!pkgName.length) return missingParamResponse();
        killByBID(pkgName);
        return staticSuccessResponse();
    });
    // An absent body still means close all apps. An invalid exclusion list must not do so.
    [server addHandlerForMethod:@"POST" path:@"/killAll" requestClass:[GCDWebServerDataRequest class]
                  processBlock:^GCDWebServerResponse *(GCDWebServerDataRequest *request) {
        NSArray *excludedApps = @[];
        if (request.data.length) {
            NSError *error = nil;
            id body = [NSJSONSerialization JSONObjectWithData:request.data options:0 error:&error];
            if (error || !MKSIsStringArray(body)) return MKSClientError(@"Expected an array of bundle identifiers");
            excludedApps = body;
        }
        killAll(excludedApps);
        return dataResponse(@{@"status": @"success", @"receivedItems": @(excludedApps.count)});
    }];
    addGETHandler(server, @"/switchApp", ^GCDWebServerResponse *(GCDWebServerRequest *request) {
        NSString *pkgName = MKSString(request.query[@"pkgName"]);
        if (!pkgName.length) return missingParamResponse();
        bringAppForeground(pkgName);
        return staticSuccessResponse();
    });
}

static void initVpnHandle(GCDWebsocketServer *server) {
    addGETHandler(server, @"/vpnStatus", ^GCDWebServerResponse *(GCDWebServerRequest *request) {
        return dataResponse(@{@"status": @"success", @"data": [DeviceConfigurator isVPNEnabled] ? @"open" : @"close"});
    });
    addGETHandler(server, @"/turnOnVPN", ^GCDWebServerResponse *(GCDWebServerRequest *request) {
        [DeviceConfigurator turnOnVPN];
        return staticSuccessResponse();
    });
    addGETHandler(server, @"/turnOffVPN", ^GCDWebServerResponse *(GCDWebServerRequest *request) {
        [DeviceConfigurator turnOffVPN];
        return staticSuccessResponse();
    });
}

static void initSettingHandle(GCDWebsocketServer *server) {
    addGETHandler(server, @"/getAllSetting", ^GCDWebServerResponse *(GCDWebServerRequest *request) {
        return dataResponse(@{@"status": @"success", @"timeZone": [DeviceConfigurator currentTimeZone] ?: @"",
            @"lang": [DeviceConfigurator currentLanguage] ?: @"", @"locale": [DeviceConfigurator currentLocale] ?: @""});
    });
    addGETHandler(server, @"/currentTimeZone", ^GCDWebServerResponse *(GCDWebServerRequest *request) {
        return dataResponse(@{@"status": @"success", @"data": [DeviceConfigurator currentTimeZone] ?: @""});
    });
    addGETHandler(server, @"/currentLanguage", ^GCDWebServerResponse *(GCDWebServerRequest *request) {
        return dataResponse(@{@"status": @"success", @"data": [DeviceConfigurator currentLanguage] ?: @""});
    });
    addGETHandler(server, @"/currentLocale", ^GCDWebServerResponse *(GCDWebServerRequest *request) {
        return dataResponse(@{@"status": @"success", @"data": [DeviceConfigurator currentLocale] ?: @""});
    });
    addGETHandler(server, @"/setLocale", ^GCDWebServerResponse *(GCDWebServerRequest *request) {
        NSString *locale = MKSString(request.query[@"locale"]);
        if (!locale.length) return missingParamResponse();
        [DeviceConfigurator setCurrentLocale:locale];
        return staticSuccessResponse();
    });
    addGETHandler(server, @"/setLanguage", ^GCDWebServerResponse *(GCDWebServerRequest *request) {
        NSString *lang = MKSString(request.query[@"lang"]);
        if (!lang.length) return missingParamResponse();
        [DeviceConfigurator setCurrentLanguage:lang];
        return staticSuccessResponse();
    });
    addGETHandler(server, @"/setCurrentTimeZone", ^GCDWebServerResponse *(GCDWebServerRequest *request) {
        NSString *timeZone = MKSString(request.query[@"timeZone"]);
        if (!timeZone.length || ![NSTimeZone timeZoneWithName:timeZone]) return missingParamResponse();
        [DeviceConfigurator setCurrentTimeZone:timeZone];
        return staticSuccessResponse();
    });
    [server addHandlerForMethod:@"POST" path:@"/setAllSetting" requestClass:[GCDWebServerDataRequest class]
                  processBlock:^GCDWebServerResponse *(GCDWebServerDataRequest *request) {
        NSError *error = nil;
        NSDictionary *body = MKSJSONDictionary(request.data, &error);
        if (!body) return jsonFormatErrorResponse();
        // Keep query parameters compatible with existing clients, while supporting a JSON-only request.
        id timeZoneValue = request.query[@"timeZone"] ?: body[@"timeZone"];
        id langValue = request.query[@"lang"] ?: body[@"lang"];
        id localeValue = request.query[@"locale"] ?: body[@"locale"];
        NSString *timeZone = MKSString(timeZoneValue);
        NSString *lang = MKSString(langValue);
        NSString *locale = MKSString(localeValue);
        if ((!timeZoneValue && !langValue && !localeValue) ||
            (timeZoneValue && (!timeZone.length || ![NSTimeZone timeZoneWithName:timeZone])) ||
            (langValue && !lang.length) || (localeValue && !locale.length)) return missingParamResponse();
        // Do not overwrite carrier preferences for a request containing only language / locale settings.
        if (body[@"opts"] || body[@"country"] || body[@"country_name"]) {
            if (![NSPropertyListSerialization propertyList:body isValidForFormat:NSPropertyListBinaryFormat_v1_0] ||
                (body[@"opts"] && ![body[@"opts"] isKindOfClass:[NSArray class]])) {
                return MKSClientError(@"Invalid carrier settings");
            }
            for (id item in body[@"opts"]) {
                if (![item isKindOfClass:[NSDictionary class]]) return MKSClientError(@"Invalid carrier settings");
            }
            if (!processReceivedJSONData(body)) return MKSServerError(@"Failed to save carrier settings");
        }
        if (locale) [DeviceConfigurator setCurrentLocale:locale];
        if (timeZone) [DeviceConfigurator setCurrentTimeZone:timeZone];
        if (lang) [DeviceConfigurator setCurrentLanguage:lang];
        return staticSuccessResponse();
    }];
}

static void initScreenHandle(GCDWebsocketServer *server) {
    addGETHandler(server, @"/pressPowerBtn", ^GCDWebServerResponse *(GCDWebServerRequest *request) {
        dispatch_async(MKSInputQueue(), ^{ [[STHIDEventGenerator sharedGenerator] powerPress]; });
        return staticSuccessResponse();
    });
    addGETHandler(server, @"/resetDirtyFrameCount", ^GCDWebServerResponse *(GCDWebServerRequest *request) {
        [Screen resetDirtyFrameCount];
        return staticSuccessResponse();
    });
    addGETHandler(server, @"/screenshot", ^GCDWebServerResponse *(GCDWebServerRequest *request) {
        double quality;
        if (!MKSReadNumber(request.query[@"quality"], 0, 1, &quality)) return missingParamResponse();
        NSError *error = nil;
        NSData *image = [Screen takeScreenshotWithQuality_v2:quality error:&error];
        if (error) return MKSServerError(error.localizedDescription);
        if (!image.length) {
            GCDWebServerResponse *response = [GCDWebServerResponse response];
            response.statusCode = kGCDWebServerHTTPStatusCode_NoContent;
            [response setValue:@"no-store" forAdditionalHeader:@"Cache-Control"];
            return MKSApplyCORS(response);
        }
        return imageResponse(image, @"image/jpeg");
    });
    addGETHandler(server, @"/screenshot_v2", ^GCDWebServerResponse *(GCDWebServerRequest *request) {
        double quality;
        if (!MKSReadNumber(request.query[@"quality"], 0, 1, &quality)) return missingParamResponse();
        return imageResponse([Screen takeScreenshotWithQuality:quality], @"image/jpeg");
    });
    addGETHandler(server, @"/screenshot_original", ^GCDWebServerResponse *(GCDWebServerRequest *request) {
        return imageResponse([Screen takeScreenshot_v2], @"image/png");
    });
    addGETHandler(server, @"/screenshot_original_old", ^GCDWebServerResponse *(GCDWebServerRequest *request) {
        return imageResponse([Screen takeScreenshot], @"image/png");
    });
    addGETHandler(server, @"/screenshotStream", ^GCDWebServerResponse *(GCDWebServerRequest *request) {
        double quality;
        int fps;
        if (!MKSReadNumber(request.query[@"quality"], 0, 1, &quality) ||
            !MKSReadInteger(request.query[@"fps"], 1, 60, &fps)) return missingParamResponse();
        return MKSApplyCORS([MKSScreenshotStream responseWithQuality:quality fps:fps]);
    });
}

static GCDWebServerResponse *setTrackingAuthorization(NSString *pkgName, BOOL reset) {
    if (!pkgName.length) return missingParamResponse();
    LSApplicationProxy *app = [LSApplicationProxy applicationProxyForIdentifier:pkgName];
    if (!app.bundleURL) return MKSClientError(@"Application bundle not found");
    CFBundleRef bundle = CFBundleCreate(kCFAllocatorDefault, (__bridge CFURLRef)app.bundleURL);
    if (!bundle) return MKSServerError(@"Failed to open application bundle");
    if (reset) TCCAccessResetForBundle(kTCCServiceUserTracking, bundle);
    else TCCAccessSetForBundle(kTCCServiceUserTracking, bundle, YES);
    CFRelease(bundle);
    return staticSuccessResponse();
}

static void initDeviceHandle(GCDWebsocketServer *server) {
    addGETHandler(server, @"/resetAV", ^GCDWebServerResponse *(GCDWebServerRequest *request) {
        NSString *pkgName = MKSString(request.query[@"pkgName"]);
        if (!pkgName.length) return missingParamResponse();
        resetIDFA();
        resetIDFV(pkgName);
        return dataResponse(getApplication(pkgName) ?: @{});
    });
    addGETHandler(server, @"/resetAuth", ^GCDWebServerResponse *(GCDWebServerRequest *request) {
        return setTrackingAuthorization(MKSString(request.query[@"pkgName"]), YES);
    });
    addGETHandler(server, @"/setADAuth", ^GCDWebServerResponse *(GCDWebServerRequest *request) {
        return setTrackingAuthorization(MKSString(request.query[@"pkgName"]), NO);
    });
    MKSAddJSONHandler(server, @"/keychain", ^GCDWebServerResponse *(NSDictionary *body) {
        NSString *type = MKSString(body[@"type"]);
        NSString *key = MKSString(body[@"key"]);
        if (!type.length) return missingParamResponse();
        NSString *tool = MKSShellQuote(jbroot(@"/usr/local/bin/keychain_clear"));
        if ([type isEqualToString:@"query"]) {
            NSString *output = runCommand([tool stringByAppendingString:@" -l"]);
            if (!output) return MKSServerError(@"Failed to launch keychain tool");
            return dataResponse(@{@"status": @"success", @"data": output});
        } else if ([type isEqualToString:@"remove"]) {
            if (!key.length) return missingParamResponse();
            if (!runCommand([NSString stringWithFormat:@"%@ -r -g %@", tool, MKSShellQuote(key)])) {
                return MKSServerError(@"Failed to launch keychain tool");
            }
        } else if ([type isEqualToString:@"removeAll"]) {
            if (!runCommand([tool stringByAppendingString:@" -r -a"])) return MKSServerError(@"Failed to launch keychain tool");
        } else {
            return MKSClientError(@"Invalid keychain operation");
        }
        return staticSuccessResponse();
    });
    addGETHandler(server, @"/GPT_PATH", ^GCDWebServerResponse *(GCDWebServerRequest *request) {
        return dataResponse(@{@"status": @"success", @"data": jbroot(@"/var/jb/var/mobile/gptdata/")});
    });
    addGETHandler(server, @"/setAFIP", ^GCDWebServerResponse *(GCDWebServerRequest *request) {
        NSString *ip = MKSString(request.query[@"ip"]);
        if (!ip.length) return missingParamResponse();
        NSString *path = [jbroot(@"/var/mobile") stringByAppendingPathComponent:@"com.csmk.afIP.plist"];
        if (![@{@"afIP": ip} writeToFile:path atomically:YES]) return MKSServerError(@"Failed to save IP settings");
        return staticSuccessResponse();
    });
    addGETHandler(server, @"/setLocation", ^GCDWebServerResponse *(GCDWebServerRequest *request) {
        NSString *latitude = MKSString(request.query[@"Latitude"]);
        NSString *longitude = MKSString(request.query[@"Longitude"]);
        if (!MKSReadNumber(latitude, -90, 90, NULL) || !MKSReadNumber(longitude, -180, 180, NULL)) {
            return missingParamResponse();
        }
        NSString *path = [jbroot(@"/var/mobile") stringByAppendingPathComponent:@"com.csmk.locationfaker.plist"];
        if (![@{@"Latitude": latitude, @"Longitude": longitude} writeToFile:path atomically:YES]) {
            return MKSServerError(@"Failed to save location settings");
        }
        if (!runCommand(@"killall -9 locationd")) return MKSServerError(@"Failed to restart location service");
        return staticSuccessResponse();
    });
    addGETHandler(server, @"/deviceInfo", ^GCDWebServerResponse *(GCDWebServerRequest *request) {
        int type;
        if (!MKSReadInteger(request.query[@"type"], 0, INT_MAX, &type)) return missingParamResponse();
        NSError *error = nil;
        NSString *info = getDeviceInfoFromRawData(type, &error);
        if (error) return MKSClientError(error.localizedDescription);
        return dataResponse(@{@"status": @"success", @"data": info ?: @""});
    });
    addGETHandler(server, @"/currApp", ^GCDWebServerResponse *(GCDWebServerRequest *request) {
        return dataResponse(@{@"status": @"success", @"data": getFrontMostApplication() ?: @""});
    });
    addGETHandler(server, @"/accounts", ^GCDWebServerResponse *(GCDWebServerRequest *request) {
        NSMutableArray *accountInfos = [NSMutableArray array];
        for (SSAccount *account in getAllAccount()) {
            [accountInfos addObject:@{
                @"isActive": @([account isActive]), @"isLocalAccount": @([account isLocalAccount]),
                @"firstName": [account firstName] ?: @"", @"lastName": [account lastName] ?: @"",
                @"accountName": [account accountName] ?: @"", @"storeFrontIdentifier": [account storeFrontIdentifier] ?: @""
            }];
        }
        return dataResponse(@{@"status": @"success", @"data": accountInfos});
    });
    addGETHandler(server, @"/rebootUserspace", ^GCDWebServerResponse *(GCDWebServerRequest *request) {
        rebootUserspace();
        
        return staticSuccessResponse();
    });
}

static void initInputHandle(GCDWebsocketServer *server) {
    addGETHandler(server, @"/pressHome", ^GCDWebServerResponse *(GCDWebServerRequest *request) {
        dispatch_async(MKSInputQueue(), ^{ [[STHIDEventGenerator sharedGenerator] menuPress]; });
        return staticSuccessResponse();
    });
    addGETHandler(server, @"/doublePressHome", ^GCDWebServerResponse *(GCDWebServerRequest *request) {
        dispatch_async(MKSInputQueue(), ^{ [[STHIDEventGenerator sharedGenerator] menuDoublePress]; });
        return staticSuccessResponse();
    });
    addGETHandler(server, @"/hideKeyboard", ^GCDWebServerResponse *(GCDWebServerRequest *request) {
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"com.csmk.keyboardcontrol" object:nil
            userInfo:@{@"task_id": @(2), @"task_content": @(1)} deliverImmediately:YES];
        return staticSuccessResponse();
    });
    MKSAddJSONHandler(server, @"/input", ^GCDWebServerResponse *(NSDictionary *body) {
        NSString *text = MKSString(body[@"text"]);
        if (!text) return missingParamResponse();
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"com.csmk.keyboardcontrol" object:nil
            userInfo:@{@"task_id": @(1), @"task_content": text} deliverImmediately:YES];
        return staticSuccessResponse();
    });
    MKSAddJSONHandler(server, @"/keypress", ^GCDWebServerResponse *(NSDictionary *body) {
        NSString *text = MKSString(body[@"text"]);
        if (!text) return missingParamResponse();
        // Enumerate composed characters so surrogate pairs are never split.
        __block NSUInteger index = 0;
        [text enumerateSubstringsInRange:NSMakeRange(0, text.length) options:NSStringEnumerationByComposedCharacterSequences
            usingBlock:^(NSString *character, NSRange range, NSRange enclosingRange, BOOL *stop) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(index++ * 0.1 * NSEC_PER_SEC)), MKSInputQueue(), ^{
                    [[STHIDEventGenerator sharedGenerator] keyPress:character];
                });
            }];
        return staticSuccessResponse();
    });
    MKSAddJSONHandler(server, @"/runShell", ^GCDWebServerResponse *(NSDictionary *body) {
        NSString *command = MKSString(body[@"cmd"]);
        if (!command.length) return missingParamResponse();
        NSString *output = runCommand(command);
        if (!output) return MKSServerError(@"Failed to execute command");
        return dataResponse(@{@"status": @"success", @"data": output});
    });
    addGETHandler(server, @"/del", ^GCDWebServerResponse *(GCDWebServerRequest *request) {
        NSString *num = MKSString(request.query[@"num"]);
        if (!MKSReadInteger(num, 0, INT_MAX, NULL)) return missingParamResponse();
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"com.csmk.keyboardcontrol" object:nil
            userInfo:@{@"task_id": @(4), @"task_content": num} deliverImmediately:YES];
        return staticSuccessResponse();
    });
    addGETHandler(server, @"/moveCursor", ^GCDWebServerResponse *(GCDWebServerRequest *request) {
        NSString *num = MKSString(request.query[@"num"]);
        if (!MKSReadInteger(num, INT_MIN, INT_MAX, NULL)) return missingParamResponse();
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"com.csmk.keyboardcontrol" object:nil
            userInfo:@{@"task_id": @(3), @"task_content": num} deliverImmediately:YES];
        return staticSuccessResponse();
    });
    MKSAddJSONHandler(server, @"/touch", ^GCDWebServerResponse *(NSDictionary *body) {
        if (!MKSIsValidTouch(body)) return missingParamResponse();
        CGPoint point = CGPointMake([body[@"x"] doubleValue], [body[@"y"] doubleValue]);
        NSString *type = body[@"type"];
        dispatch_async(MKSInputQueue(), ^{
            STHIDEventGenerator *generator = [STHIDEventGenerator sharedGenerator];
            if ([type isEqualToString:@"up"]) [generator liftUp:point];
            else if ([type isEqualToString:@"tap"]) [generator tap:point];
            else [generator touchDown:point];
        });
        return staticSuccessResponse();
    });
    MKSAddJSONHandler(server, @"/setClip", ^GCDWebServerResponse *(NSDictionary *body) {
        NSString *text = MKSString(body[@"text"]);
        if (!text) return missingParamResponse();
        MKSOnMainThread(^{
            [UIPasteboard generalPasteboard].string = text;
        });
        return staticSuccessResponse();
    });
    addGETHandler(server, @"/getClip", ^GCDWebServerResponse *(GCDWebServerRequest *request) {
        __block NSString *text;
        MKSOnMainThread(^{
            text = [UIPasteboard generalPasteboard].string;
        });
        return dataResponse(@{@"status": @"success", @"data": text ?: @"获取失败"});
    });
}

void initHandle(GCDWebsocketServer *server) {
    [server addHandlerForMethod:@"OPTIONS" pathRegex:@"^/" requestClass:[GCDWebServerRequest class]
                  processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
        GCDWebServerResponse *response = MKSApplyCORS([GCDWebServerResponse response]);
        response.statusCode = kGCDWebServerHTTPStatusCode_NoContent;
        [response setValue:@"43200" forAdditionalHeader:@"Access-Control-Max-Age"];
        return response;
    }];
    // Register the static fallback first so API routes take precedence in GCDWebServer's LIFO order.
    [server addGETHandlerForBasePath:@"/" directoryPath:jbroot(@"/usr/lib/mks_dist")
        indexFilename:@"index.html" cacheAge:3600 allowRangeRequests:YES];
    initScreenHandle(server);
    initWebSocket(server);
    initDeviceHandle(server);
    initInputHandle(server);
    initAppHandle(server);
    initToastHandle(server);
    initVpnHandle(server);
    initSettingHandle(server);
}

BOOL processReceivedJSONData(NSDictionary *body) {
    if (![body isKindOfClass:[NSDictionary class]] ||
        ![NSPropertyListSerialization propertyList:body isValidForFormat:NSPropertyListBinaryFormat_v1_0] ||
        (body[@"opts"] && ![body[@"opts"] isKindOfClass:[NSArray class]])) return NO;
    NSMutableArray *operators = [NSMutableArray array];
    for (id option in body[@"opts"]) {
        if (![option isKindOfClass:[NSDictionary class]]) return NO;
        [operators addObject:@{
            @"country": body[@"country"] ?: @"", @"country_code": body[@"country_code"] ?: @"",
            @"country_name": body[@"country_name"] ?: @"", @"ios": body[@"ios"] ?: @"",
            @"mcc": option[@"mcc"] ?: @"", @"mnc": option[@"mnc"] ?: @"",
            @"name": option[@"name"] ?: @"", @"network": option[@"network"] ?: @""
        }];
    }
    @synchronized ([DeviceConfigurator class]) {
        NSString *path = jbroot(@"/var/mobile/Library/Preferences/GptXinjiParamsData");
        NSMutableDictionary *preferences = [NSMutableDictionary dictionaryWithContentsOfFile:path] ?: [NSMutableDictionary dictionary];
        preferences[@"autoOprData"] = @{@"ControyName": body[@"country_name"] ?: @"", @"OperArr": operators};
        return [preferences writeToFile:path atomically:YES];
    }
}
