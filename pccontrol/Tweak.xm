#include <CoreFoundation/CFUserNotification.h>
#include "IOKit+SPI.h"
#import "Common.h"
#import "Screen.h"
#import "AlertBox.h"
#import "WebServer.h"
#import "AppStore.h"
#import "Process.h"
#import "IOKitSPI.h"


%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)arg1
{
    %orig;
    CGFloat screen_scale = [[UIScreen mainScreen] scale];

    CGFloat width = [UIScreen mainScreen].bounds.size.width;
    CGFloat height = [UIScreen mainScreen].bounds.size.height;

    [Screen setScreenScale:screen_scale];    

    [Screen setScreenPTSize:(width<height?width:height) height:(width>height?width:height)];  

    startWebServer();
}
%end