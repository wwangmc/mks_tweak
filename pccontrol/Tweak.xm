
#import <IOKit/hid/IOHIDService.h>
#include <CoreFoundation/CFUserNotification.h>

#import "Touch.h"
#import "Common.h"
#import "Screen.h"
#import "AlertBox.h"
#import "WebServer.h"
#import "AppStore.h"
#import "Process.h"

void *(*IOHIDEventAppendEventOld)(IOHIDEventRef parent, IOHIDEventRef child);


IOHIDEventSystemClientRef ioHIDEventSystemForPopupDectect = NULL;


/*
Get the sender id and unregister itself.
*/
static CFTimeInterval startTime = 0;
// 静音键
static CFTimeInterval siledStartTime = 0;
// perform some action
static void popupWindowCallBack(void* target, void* refcon, IOHIDServiceRef service, IOHIDEventRef event)
{
    if (IOHIDEventGetType(event) == kIOHIDEventTypeKeyboard)
    {
        
        /*uint32_t usage = (uint32_t)IOHIDEventGetIntegerValue(event, kIOHIDEventFieldKeyboardUsage);
        
        // 实时显示按键的 Usage 值
        NSString *message = [NSString stringWithFormat:@"按键 Usage: %d", usage];
        showAlertBox(@"按键检测", message, 2); // 2秒后自动关闭
        */

        int buttonId = IOHIDEventGetIntegerValue(event, kIOHIDEventFieldKeyboardUsage);
        // if (buttonId == 46)
        // {
        //     // 拨动输入密码
        //     currPwd();
        //     // 如果为15+拨动两下重启用户空间
        //     if (@available(iOS 15.0, *)) {
        //         CFTimeInterval currentTime = CACurrentMediaTime();
        //         if (currentTime - siledStartTime > 2)
        //         {
        //             siledStartTime = CACurrentMediaTime();
        //             return;
        //         }
        //         showAlertBox(@"按键检测", @"触发机关15+系统会重启用户空间", 2);
        //         rebootUserspace();
        //     }
        // }

        // 音量减234 音量加233
        if (buttonId == 233 && IOHIDEventGetIntegerValue(event, kIOHIDEventFieldKeyboardDown) == 0)
        {
            CFTimeInterval currentTime = CACurrentMediaTime();
            if (currentTime - startTime > 0.4)
            {
                startTime = CACurrentMediaTime();
                return;
            }
            currPwd();
        }
    }
}

/**
Start the callback for setting sender id
*/
void startPopupListeningCallBack()
{
    ioHIDEventSystemForPopupDectect = IOHIDEventSystemClientCreate(kCFAllocatorDefault);

    IOHIDEventSystemClientScheduleWithRunLoop(ioHIDEventSystemForPopupDectect, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    IOHIDEventSystemClientRegisterEventCallback(ioHIDEventSystemForPopupDectect, (IOHIDEventSystemClientEventCallback)popupWindowCallBack, NULL, NULL);
    //NSLog(@"### com.zjx.springboard: screen width: %f, screen height: %f", device_screen_width, device_screen_height);
}




%ctor{

}

%hook SpringBoard
#define CGRectSetPos( r, x, y ) CGRectMake( x, y, r.size.width, r.size.height )

- (void)applicationDidFinishLaunching:(id)arg1
{
    %orig;
    CGFloat screen_scale = [[UIScreen mainScreen] scale];

    CGFloat width = [UIScreen mainScreen].bounds.size.width;
    CGFloat height = [UIScreen mainScreen].bounds.size.height;

    [Screen setScreenScale:screen_scale];    

    [Screen setScreenPTSize:(width<height?width:height) height:(width>height?width:height)];  
    initSenderId();
    // init touch screensize. Temporarily put this line here. Will be removed.
    initTouchGetScreenSize();

    startWebServer();
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{  
        startPopupListeningCallBack();
        CFRunLoopRun();
    });

}
%end