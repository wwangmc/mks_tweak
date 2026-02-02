//
//  TCC.h
//  AppData
//
//  Created by udevs on 21/11/2020.
//

#ifndef ADTCC_h
#define ADTCC_h
#import <UIKit/UIKit.h>

FOUNDATION_EXTERN NSString *const kTCCServiceAll;

FOUNDATION_EXTERN NSString *const kTCCServiceUserTracking;

FOUNDATION_EXTERN int TCCAccessResetForBundle(NSString *service, CFBundleRef bundle);

FOUNDATION_EXTERN int TCCAccessSetForBundle(NSString *service, CFBundleRef bundle, BOOL access);

FOUNDATION_EXTERN NSArray<NSDictionary *> *TCCAccessCopyInformationForBundle(CFBundleRef bundle);

#endif /* TCC_h */