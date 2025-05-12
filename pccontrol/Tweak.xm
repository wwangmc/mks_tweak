#include "headers/BKUserEventTimer.h"
#import <IOKit/hid/IOHIDService.h>
#include "socketConfig.h"

#include "headers/CFUserNotification.h"

#import "Touch.h"
#import "Common.h"
#import "Screen.h"
#import "AlertBox.h"
#import "WebServer.h"

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
        if (IOHIDEventGetIntegerValue(event, kIOHIDEventFieldKeyboardUsage) == 234 && IOHIDEventGetIntegerValue(event, kIOHIDEventFieldKeyboardDown) == 0)
        {
            CFTimeInterval currentTime = CACurrentMediaTime();
            if (currentTime - startTime > 0.4)
            {
                startTime = CACurrentMediaTime();
                return;
            }
            showAlertBox(@"通知",@"音量减被按下",10);
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

        CGFloat width = [UIScreen mainScreen].bounds.size.width * screen_scale;
        CGFloat height = [UIScreen mainScreen].bounds.size.height * screen_scale;

        [Screen setScreenSize:(width<height?width:height) height:(width>height?width:height)];    

        initSenderId();
        startPopupListeningCallBack();

        // init touch screensize. Temporarily put this line here. Will be removed.
        initTouchGetScreenSize();
        
        CFRunLoopRun();
    });

}
%end