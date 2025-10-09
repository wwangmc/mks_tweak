#import "AppStore.h"
#import <objc/runtime.h>
#import "AlertBox.h"
#import "Request.h"
#import <Foundation/NSDistributedNotificationCenter.h>

NSArray * getAllAccount()
{
    SSAccountStore *accountStore = [objc_getClass("SSAccountStore") defaultStore];
    NSArray *accounts = [accountStore accounts];
    return accounts;
}

NSString * currAccount()
{
    NSArray *accounts = getAllAccount();

    NSMutableArray *accountInfos = [NSMutableArray array];
    
    for (SSAccount *account in accounts) {
        if([account isActive]){
            return [account accountName] ?: @"";
        }
    }
    return @"";
}
