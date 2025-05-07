#include "Process.h"
#include "Common.h"
int (*openApp)(CFStringRef, Boolean);
// 这里的路径不需要无根处理
static void* sbServices = dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_LAZY);

int switchProcessForegroundFromRawData(UInt8 *eventData)
{
    return bringAppForeground([NSString stringWithFormat:@"%s", eventData]);
}

int bringAppForeground(NSString *appIdentifier)
{
    CFStringRef appBundleName = CFStringCreateWithFormat(NULL, NULL, CFSTR("%@"), appIdentifier);
    //[NSString stringWithFormat:@"%s", eventData];
    NSLog(@"### com.zjx.springboard: Switch to application: %@", appBundleName);
    if (!openApp)
        openApp = (int(*)(CFStringRef, Boolean))dlsym(sbServices,"SBSLaunchApplicationWithIdentifier");

    return openApp(appBundleName, false);
}

id getFrontMostApplication()
{
    //TODO: might cause problem here. Both _accessibilityFrontMostApplication failed or front most application springboard will cause app be nil.
    __block id app = nil;
    dispatch_sync(dispatch_get_main_queue(), ^{
        @try{
            SpringBoard *springboard = (SpringBoard*)[%c(SpringBoard) sharedApplication];
            app = [springboard _accessibilityFrontMostApplication];
        }
        @catch (NSException *exception) {
            NSLog(@"com.zjx.springboard: Debug: %@", exception.reason);
        }
        });
    return app;
}