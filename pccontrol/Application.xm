#import <MobileCoreServices/LSApplicationProxy.h>
#import <MobileCoreServices/LSApplicationWorkspace.h>
#import "Application.h"
#import "AlertBox.h"

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

BOOL uninstall(NSString *bundleId)
{
    LSApplicationProxy* appProxy = [LSApplicationProxy applicationProxyForIdentifier:bundleId];
    if(!appProxy){
        NSLog(@"应用未安装");
        showAlertBox(@"卸载结果",@"应用未安装",2);
        return true;
    }
    // 应用可卸载
    if (appProxy.isDeletable) {
        BOOL success = [[LSApplicationWorkspace defaultWorkspace] uninstallApplication:bundleId withOptions:nil];
        if(!success){
            showAlertBox(@"卸载结果",@"卸载失败",2);
            return false;
        }
        return true;
    }
    showAlertBox(@"卸载结果",@"该应用不可卸载",2);
    return false;
}