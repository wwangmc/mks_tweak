#ifndef APPSTORE_H
#define APPSTORE_H
#import <UIKit/UIKit.h>

@interface SSAccount
- (BOOL)isActive;
- (void)setActive:(BOOL)arg1;
- (BOOL)isLocalAccount;
- (NSString *)firstName;
- (NSString *)lastName;
- (NSString *)accountName;
- (NSString *)storeFrontIdentifier;
@end

@interface SSAccountStore
+ (id)defaultStore;
- (NSArray *)accounts;
- (BOOL)saveAccount:(id)arg1 verifyCredentials:(BOOL)arg2 error:(id*)arg3;
- (void)removeAccount:(id)arg1 error:(id*)arg2;
@end

NSArray * getAllAccount();

NSString * currAccount();

NSString * currPwd();

#endif