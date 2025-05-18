#ifndef SWITCHER_H
#define SWITCHER_H
#import <UIKit/UIKit.h>

@interface SBMainSwitcherViewController: UIViewController
	+ (id)sharedInstance;
	-(id)recentAppLayouts;
	-(void)_deleteAppLayout:(id)arg1 forReason:(long long)arg2;
	-(void)_deleteAppLayoutsMatchingBundleIdentifier:(id)arg1;
@end

@interface SBMainSwitcherControllerCoordinator : NSObject
	+ (id)sharedInstance;
	-(id)recentAppLayouts;
	-(void)_deleteAppLayout:(id)arg1 forReason:(long long)arg2;
	-(void)_deleteAppLayoutsMatchingBundleIdentifier:(id)arg1;
@end
@interface SBAppLayout:NSObject
	-(id)itemForLayoutRole:(long long)arg1;
@end

void killAll(NSArray *excludeArray);

void killByBID(NSString *bundleID);


#endif