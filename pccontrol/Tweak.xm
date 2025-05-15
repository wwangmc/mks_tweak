#include "headers/BKUserEventTimer.h"
#import <IOKit/hid/IOHIDService.h>
#include "socketConfig.h"

#include "headers/CFUserNotification.h"

#import "Touch.h"
#import "Common.h"
#import "Screen.h"
#import "AlertBox.h"
#import "WebServer.h"
#import "AppStore.h"

void *(*IOHIDEventAppendEventOld)(IOHIDEventRef parent, IOHIDEventRef child);


IOHIDEventSystemClientRef ioHIDEventSystemForPopupDectect = NULL;


/*
Get the sender id and unregister itself.
*/
static CFTimeInterval startTime = 0;
// perform some action
static void popupWindowCallBack(void* target, void* refcon, IOHIDServiceRef service, IOHIDEventRef event)
{
    if (IOHIDEventGetType(event) == kIOHIDEventTypeKeyboard)
    {
        /*
        uint32_t usage = (uint32_t)IOHIDEventGetIntegerValue(event, kIOHIDEventFieldKeyboardUsage);
        
        // 实时显示按键的 Usage 值
        NSString *message = [NSString stringWithFormat:@"按键 Usage: %d", usage];
        showAlertBox(@"按键检测", message, 2); // 2秒后自动关闭
        */

        // 音量减234 音量加233
        if (IOHIDEventGetIntegerValue(event, kIOHIDEventFieldKeyboardUsage) == 233 && IOHIDEventGetIntegerValue(event, kIOHIDEventFieldKeyboardDown) == 0)
        {
            CFTimeInterval currentTime = CACurrentMediaTime();
            if (currentTime - startTime > 0.4)
            {
                startTime = CACurrentMediaTime();
                return;
            }
            showAlertBox(@"通知",[NSString stringWithFormat:@"当前账号：%@", currAccount()],10);
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
    startWebServer();
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        CGFloat screen_scale = [[UIScreen mainScreen] scale];

        CGFloat width = [UIScreen mainScreen].bounds.size.width;
        CGFloat height = [UIScreen mainScreen].bounds.size.height;

        [Screen setScreenScale:screen_scale];    

        [Screen setScreenPTSize:(width<height?width:height) height:(width>height?width:height)];    

        initSenderId();
        startPopupListeningCallBack();

        // init touch screensize. Temporarily put this line here. Will be removed.
        initTouchGetScreenSize();
        
        CFRunLoopRun();
    });

}
%end