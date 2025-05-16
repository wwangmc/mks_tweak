#ifndef APPLICATION_H
#define APPLICATION_H
NSMutableArray * getAllApplication();
NSDictionary * getApplication(NSString *bundleId);
BOOL uninstall(NSString *bundleId);
#endif