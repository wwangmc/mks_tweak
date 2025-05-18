#import "Switcher.h"

void killAll(NSArray *excludeArray) {
    dispatch_async(dispatch_get_main_queue(), ^{
        // pressHome();
        //remove the apps
        NSLog(@"killAll running");
        id mainSwitcher;
        if (@available(iOS 16.0, *)) {
            mainSwitcher = [%c(SBMainSwitcherControllerCoordinator) sharedInstance];
        } else {
            mainSwitcher = [%c(SBMainSwitcherViewController) sharedInstance];
        }

        NSArray *items = [mainSwitcher recentAppLayouts];
        
        // 处理 excludeArray 为 nil 的情况
        NSArray *safeExcludeArray = excludeArray ?: @[];
        NSSet *excludeSet = [NSSet setWithArray:safeExcludeArray];

        for (SBAppLayout *item in items) {
            NSString *bundleID = [[item itemForLayoutRole:1] bundleIdentifier];
            
            // 如果 bundleID 不在排除列表中，则关闭应用
            if (bundleID && ![excludeSet containsObject:bundleID]) {
                if (@available(iOS 14.0, *)) {
                    // 14以上的版本
                    [mainSwitcher _deleteAppLayoutsMatchingBundleIdentifier:bundleID];
                } else {
                    // 14以下版本
                    [mainSwitcher _deleteAppLayout:item forReason:1];
                }
            }
        }
    });
}

void killByBID(NSString *bundleID)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        // pressHome();
        //remove the apps
        NSLog(@"killAll runing");
        id mainSwitcher;
        if (@available(iOS 16.0, *))
            mainSwitcher = [%c(SBMainSwitcherControllerCoordinator) sharedInstance];
        else
            mainSwitcher = [%c(SBMainSwitcherViewController) sharedInstance];

        if (@available(iOS 14.0, *)){
            [mainSwitcher _deleteAppLayoutsMatchingBundleIdentifier:bundleID];
        }else{
            NSArray *items = [mainSwitcher recentAppLayouts];
            for(SBAppLayout *item in items)
            {
                if([[[item itemForLayoutRole:1] bundleIdentifier] isEqualToString:bundleID]){
                    // 14以下版本
                    [mainSwitcher _deleteAppLayout:item forReason: 1];
                    break;
                }
            }
        }

    });
}