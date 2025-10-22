@interface SSAccount
//+ (id)_countryCodeFromStorefrontIdentifier:(id)arg1;
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
//- (id)setActiveAccount:(SSAccount *)arg1 ;
- (BOOL)saveAccount:(id)arg1 verifyCredentials:(BOOL)arg2 error:(id*)arg3;
- (void)removeAccount:(id)arg1 error:(id*)arg2;
- (void)signOutAccount:(id)arg1 completion:(/*^block*/id)arg2;
- (void)signOutAllAccounts;
- (void)removeAllAccountsWithCompletion:(/*^block*/id)arg1;

@end

@interface SSDevice
+ (id)currentDevice;
- (void)reloadStoreFrontIdentifier;
@end

@interface SKUIApplicationController
- (void)_resetUserInterfaceAfterStoreFrontChange;
@end

@interface SKUIClientContext
+ (id)defaultContext;
- (SKUIApplicationController *)applicationController;
@end