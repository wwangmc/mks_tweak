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

NSString *currPwd()
{
    NSString * appleId =currAccount();
    if(appleId){
        // 调用示例
        sendGETRequest([@"http://47.96.125.116:6666/appleinfo/getPwd?appleId=" stringByAppendingString:appleId], ^(id jsonResponse, NSError *error) {
            if (error) {
                NSLog(@"请求失败: %@", error.localizedDescription);
                showAlertBox(@"错误", error.localizedDescription, 3);
                return;
            }
            if ([jsonResponse isKindOfClass:[NSDictionary class]]) {
                // showAlertBox(@"通知", [jsonResponse description], 3);
                if([jsonResponse[@"code"] intValue]== 200){
                    // 处理字典类型的JSON
                    NSLog(@"收到JSON字典: %@", jsonResponse);
                    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"com.csmk.keyboardcontrol" object:NULL userInfo:@{@"task_id": @(1), @"task_content": jsonResponse[@"data"]} deliverImmediately: true];
                    return;
                }
            } 
            showAlertBox(@"通知", @"获取失败", 3);
        });
    }
}