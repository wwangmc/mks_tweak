#include "Process.h"
#include "Common.h"
#include <roothide.h>
#include <spawn.h>

int (*openApp)(CFStringRef, Boolean);
// 这里的路径不需要无根处理
static void* sbServices = dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_LAZY);



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
    // __block id app = nil;

    __block id app = nil;

    dispatch_sync(dispatch_get_main_queue(), ^{
        SBApplication *frontMostApp = [(SpringBoard *)UIApplication.sharedApplication _accessibilityFrontMostApplication];
        if (frontMostApp){
            app = frontMostApp.bundleIdentifier;
        }else{
            // 获取失败 默认值
            app = @"";
        }
    });
    return app;

}

void rebootUserspace() {
    if (@available(iOS 15.0, *)) {
        pid_t pid;
        const char* args[] = {"launchctl", "reboot", "userspace", NULL, NULL};
        posix_spawn(&pid, jbroot("/usr/bin/launchctl"), NULL, NULL, (char* const*)args, NULL);
    }
}	