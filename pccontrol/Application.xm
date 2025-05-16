#import <MobileCoreServices/LSApplicationProxy.h>
#import <MobileCoreServices/LSApplicationWorkspace.h>
#import "Application.h"

NSDictionary * formatAppProxy(LSApplicationProxy *appProxy)
{
    if(appProxy){
            NSString *bundleVersion = [appProxy valueForKey:@"shortVersionString"] ?: @"";
            NSString *shortVersion = [appProxy valueForKey:@"bundleVersion"] ?: @"";
            NSString *applicationType = [appProxy valueForKey:@"applicationType"] ?: @"";
            
            NSDictionary *appInfo = @{
                @"applicationIdentifier": appProxy.applicationIdentifier ?: @"",
                @"localizedName": appProxy.localizedName ?: @"",
                @"bundleVersion": bundleVersion,
                @"shortVersionString": shortVersion,
                @"vendorName": [appProxy valueForKey:@"vendorName"] ?: @"",
                @"applicationType": applicationType,
                @"isInstalled": @(appProxy.isInstalled),
                @"bundleURL": appProxy.bundleURL.path ?: @"",
                @"dataContainerURL": [appProxy valueForKeyPath:@"dataContainerURL.path"] ?: @"",
                @"itemID": [appProxy valueForKey:@"itemID"] ?: @""
            };
            return appInfo;
    }
    return @{};
}
NSMutableArray * getAllApplication()
{
    NSArray<LSApplicationProxy*>* allInstalledApplications = [[LSApplicationWorkspace defaultWorkspace] allInstalledApplications];
    
    NSMutableArray *appsArray = [NSMutableArray array];
    for (LSApplicationProxy *appProxy in allInstalledApplications) {       
        NSDictionary *appInfo = formatAppProxy(appProxy);
        [appsArray addObject:appInfo];
    }
    return appsArray;
}
NSDictionary * getApplication(NSString *bundleId)
{
    LSApplicationProxy* appProxy = [LSApplicationProxy applicationProxyForIdentifier:bundleId];
    return formatAppProxy(appProxy);
}