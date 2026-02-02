
//
//  TCC.m
//  AppData
//
//  Created by udevs on 21/11/2020.
//

#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import "ADTCC.h"
/**
static NSDictionary* const commonTCCServices = @{
    @"kTCCServicePhotos": @"Photo Library",
    @"kTCCServicePhotosAdd": @"Photo Library (Add)",
    @"kTCCServiceCamera": @"Camera",
    @"kTCCServiceMicrophone": @"Microphone",
    @"kTCCServiceAddressBook": @"Contacts",
    @"kTCCServiceCalendar": @"Calendars",
    @"kTCCServiceReminders": @"Reminders",
    @"kTCCServiceWillow": @"HomeKit",
    @"kTCCServiceGameCenterFriends": @"Game Center Friends",
    @"kTCCServiceExposureNotification": @"Exposure Notifications",
    @"kTCCServiceFocusStatus": @"Focus Status",
    @"kTCCServiceUserTracking": @"User Tracking",
    @"kTCCServiceFaceID": @"Face ID",
    @"kTCCServiceMediaLibrary": @"Apple Media Library",
    @"kTCCServiceMotion": @"Motion Sensors",
    @"kTCCServiceNearbyInteraction": @"Nearby Device Interaction",
    @"kTCCServiceBluetoothAlways": @"Bluetooth (Always)",
    @"kTCCServiceBluetoothWhileInUse": @"Bluetooth (While In Use)",
    @"kTCCServiceBluetoothPeripheral": @"Bluetooth (Peripherals)",
    @"kTCCServiceLocation": @"Location"
};

*/
NSString *const kTCCServiceAll = @"kTCCServiceAll";
NSString *const kTCCServiceUserTracking = @"kTCCServiceUserTracking";

static int (*TCCAccessResetForBundle_Ptr) (NSString *, CFBundleRef);
static int (*TCCAccessSetForBundle_Ptr) (NSString *, CFBundleRef,BOOL);
static CFArrayRef (*TCCAccessCopyInformationForBundle_Ptr)(CFBundleRef);


int TCCAccessResetForBundle(NSString *service, CFBundleRef bundle) {
    return TCCAccessResetForBundle_Ptr ? TCCAccessResetForBundle_Ptr(service, bundle) : 0;
}

int TCCAccessSetForBundle(NSString *service, CFBundleRef bundle, BOOL access){
    return TCCAccessSetForBundle_Ptr ? TCCAccessSetForBundle_Ptr(service, bundle,access) : 0;
}
NSArray<NSDictionary *> *TCCAccessCopyInformationForBundle(CFBundleRef bundle) {
    if (TCCAccessCopyInformationForBundle_Ptr) {
        CFArrayRef array = TCCAccessCopyInformationForBundle_Ptr(bundle);
        NSArray *objcArray = (__bridge_transfer NSArray *)array;
        return [objcArray copy];
    }
    return NULL;
}


__attribute__((constructor))
static void initializeFunctions() {
    void *handle = dlopen("/System/Library/PrivateFrameworks/TCC.framework/TCC", RTLD_LAZY);
    if (handle) {
        TCCAccessResetForBundle_Ptr = dlsym(handle, "TCCAccessResetForBundle");
        TCCAccessSetForBundle_Ptr = dlsym(handle, "TCCAccessSetForBundle");
        TCCAccessCopyInformationForBundle_Ptr = dlsym(handle, "TCCAccessCopyInformationForBundle");
        dlclose(handle);
    }else{
        printf(@"open error");
    }
}
