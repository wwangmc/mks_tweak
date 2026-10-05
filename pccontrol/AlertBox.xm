#include "AlertBox.h"


void showAlertBox(NSString* title, NSString* content, NSTimeInterval dismissTime)
{
    NSMutableDictionary* dict = [NSMutableDictionary dictionary];
    [dict setObject: title forKey: (__bridge NSString*)kCFUserNotificationAlertHeaderKey];
    [dict setObject: content forKey: (__bridge NSString*)kCFUserNotificationAlertMessageKey];
    [dict setObject: @"Ok" forKey:(__bridge NSString*)kCFUserNotificationDefaultButtonTitleKey];
    
    SInt32 error = 0;
    CFUserNotificationRef alert = CFUserNotificationCreate(NULL, 0, kCFUserNotificationPlainAlertLevel, &error, (__bridge CFDictionaryRef)dict);
    if (!alert) {
        NSLog(@"Failed to create alert: %d", (int)error);
        return;
    }

    CFOptionFlags response;
    
     if((error) || (CFUserNotificationReceiveResponse(alert, dismissTime, &response))) {
        NSLog(@"com.zjx.springboard: alert error or no user response after %g seconds for title: %@. Content %@", dismissTime, title, content);
     }
    

    CFRelease(alert);
}
