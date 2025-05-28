#import "DeviceConfigurator.h"
#import <Foundation/Foundation.h>

dispatch_once_t onceToken;
void loadVPNPreferencesBundle()
{
    dispatch_once(&onceToken, ^{
        [[NSBundle bundleWithPath:@"/System/Library/PreferenceBundles/VPNPreferences.bundle"] load];
    });
}

void turnOnVPN()
{
    @autoreleasepool {
        loadVPNPreferencesBundle();
        VPNConnectionStore *store = [%c(VPNConnectionStore) sharedInstance];
        unsigned long long grade = [store currentOnlyConnectionGrade];
        VPNConnection *vpn = [store currentConnectionWithGrade:grade];
        [vpn connect];
    }
}

void turnOffVPN()
{
    @autoreleasepool {
        
        loadVPNPreferencesBundle();
        VPNConnectionStore *store = [%c(VPNConnectionStore) sharedInstance];
        unsigned long long grade = [store currentOnlyConnectionGrade];
        VPNConnection *vpn = [store currentConnectionWithGrade:grade];
        [vpn disconnect];
    }
}
