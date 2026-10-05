#ifndef APPLICATION_H
#define APPLICATION_H
#import <MobileCoreServices/LSApplicationWorkspace.h>
#import <MobileCoreServices/LSApplicationProxy.h>


NSMutableArray * getAllApplication();
NSDictionary * getApplication(NSString *bundleId);
BOOL uninstall(NSString *bundleId);
void resetIDFA();
void resetIDFV(NSString * bundleId);

@interface LSApplicationProxy(Private)
    @property(readonly, nonatomic) NSUUID *deviceIdentifierForAdvertising;
    @property(readonly, nonatomic) NSUUID *deviceIdentifierForVendor;
    -(BOOL)isDeletable;
@end

@interface LSApplicationWorkspace(Private)

    + (instancetype)defaultWorkspace;
    - (void)clearAdvertisingIdentifier;
    - (id)deviceIdentifierForAdvertising;
    - (void)removeDeviceIdentifierForVendorName:(id)arg1 bundleIdentifier:(id)arg2;
    - (bool)uninstallApplication:(id)arg1 withOptions:(id)arg2;
@end
#endif