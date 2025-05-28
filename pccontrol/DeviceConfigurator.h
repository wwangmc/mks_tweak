#ifndef DEVICE_CONFIG_H
#define DEVICE_CONFIG_H
#import <UIKit/UIKit.h>


@interface VPNConnection : NSObject
- (BOOL)connected;
- (BOOL)disconnected;
- (void)connect;
- (void)disconnect;
- (void)setEnabled:(BOOL)arg1;
- (BOOL)enabled;
@end


@interface VPNConnectionStore : NSObject
+ (instancetype)sharedInstance;
- (VPNConnection *)currentConnectionWithGrade:(unsigned long long)arg1;
- (unsigned long long)currentOnlyConnectionGrade;
@end


void turnOnVPN();
void turnOffVPN();

NSString * currentLanguage();
void setCurrentLanguage(NSString *language);

NSString * currentLocale();
void setCurrentLocale(NSString * locale);  // async

NSString * currentTimeZone();
void setCurrentTimeZone(NSString * timeZoneName);
#endif