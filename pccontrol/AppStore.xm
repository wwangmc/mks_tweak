#import "AppStore.h"
#import <objc/runtime.h>

NSArray * getAllAccount()
{
    SSAccountStore *accountStore = [objc_getClass("SSAccountStore") defaultStore];
    NSArray *accounts = [accountStore accounts];
    return accounts;
}