#import "DeviceConfigurator.h"
#import <objc/runtime.h>

static ALCity *(*PSCityForTimeZone)(CFTimeZoneRef timeZone);

NSString *InternationalSettingsExtractLanguageCode(NSString *languageCode) {
    languageCode = [languageCode stringByReplacingOccurrencesOfString:@"_" withString:@"-"];
    if ([languageCode hasPrefix:@"zh"]) {
        if ([languageCode hasPrefix:@"zh-Hans"] || [languageCode hasPrefix:@"zh-CN"])
            return @"zh-Hans";
        else if ([languageCode isEqualToString:@"zh-Hant-HK"] || [languageCode hasPrefix:@"zh-HK"])
            return @"zh-Hant-HK";
        else
            return @"zh-Hant";
    } else if ([languageCode hasPrefix:@"en"]) {
        if ([languageCode isEqualToString:@"en-US"])
            return @"en-US";
        else if ([languageCode isEqualToString:@"en-GB"])
            return @"en-GB";
        else if ([languageCode isEqualToString:@"en-AU"])
            return @"en-AU";
        else if ([languageCode isEqualToString:@"en-IN"])
            return @"en-IN";
        else
            return @"en";
    } else if ([languageCode hasPrefix:@"es"]) {
        if ([languageCode isEqualToString:@"es-MX"])
            return @"es-MX";
        else if ([languageCode isEqualToString:@"es-US"])
            return @"es-US";
        else if ([languageCode isEqualToString:@"es-419"])
            return @"es-419";
        else
            return @"es";
    } else if ([languageCode hasPrefix:@"fr"]) {
        if ([languageCode isEqualToString:@"fr-CA"])
            return @"fr-CA";
        else
            return @"fr";
    } else if ([languageCode hasPrefix:@"ja"]) {
        return @"ja";
    } else if ([languageCode hasPrefix:@"de"]) {
        return @"de";
    } else if ([languageCode hasPrefix:@"ru"]) {
        return @"ru";
    } else if ([languageCode hasPrefix:@"pt"]) {
        if ([languageCode isEqualToString:@"pt-BR"])
            return @"pr-BR";
        else
            return @"pt-PT";
    } else if ([languageCode hasPrefix:@"it"]) {
        return @"it";
    } else if ([languageCode hasPrefix:@"ko"]) {
        return @"ko";
    } else if ([languageCode hasPrefix:@"tr"]) {
        return @"tr";
    } else if ([languageCode hasPrefix:@"nl"]) {
        return @"nl";
    } else if ([languageCode hasPrefix:@"ar"]) {
        return @"ar";
    } else if ([languageCode hasPrefix:@"th"]) {
        return @"th";
    } else if ([languageCode hasPrefix:@"sv"]) {
        return @"sv";
    } else if ([languageCode hasPrefix:@"da"]) {
        return @"da";
    } else if ([languageCode hasPrefix:@"vi"]) {
        return @"vi";
    } else if ([languageCode hasPrefix:@"pl"]) {
        return @"pl";
    } else if ([languageCode hasPrefix:@"fi"]) {
        return @"fi";
    } else if ([languageCode hasPrefix:@"id"]) {
        return @"id";
    } else if ([languageCode hasPrefix:@"he"]) {
        return @"he";
    } else if ([languageCode hasPrefix:@"el"]) {
        return @"el";
    } else if ([languageCode hasPrefix:@"ro"]) {
        return @"ro";
    } else if ([languageCode hasPrefix:@"hu"]) {
        return @"hu";
    } else if ([languageCode hasPrefix:@"cs"]) {
        return @"cs";
    } else if ([languageCode hasPrefix:@"sk"]) {
        return @"sk";
    } else if ([languageCode hasPrefix:@"uk"]) {
        return @"uk";
    } else if ([languageCode hasPrefix:@"hr"]) {
        return @"hr";
    } else if ([languageCode hasPrefix:@"ms"]) {
        return @"ms";
    }
    return @"en";
}

@implementation DeviceConfigurator 

+ (void)loadVPNPreferencesBundle
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [[NSBundle bundleWithPath:@"/System/Library/PreferenceBundles/VPNPreferences.bundle"] load];
    });
}

+ (void)loadInternationalSettingsBundle
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [[NSBundle bundleWithPath:@"/System/Library/PreferenceBundles/InternationalSettings.bundle"] load];
    });
}

+ (void)loadGeneralSettingsUIFramework
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [[NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/Settings/GeneralSettingsUI.framework"] load];
    });
}


+ (void)turnOnVPN
{
    @autoreleasepool {
        [DeviceConfigurator loadVPNPreferencesBundle];
        VPNConnectionStore *store = [objc_getClass("VPNConnectionStore") sharedInstance];
        unsigned long long grade = [store currentOnlyConnectionGrade];
        VPNConnection *vpn = [store currentConnectionWithGrade:grade];
        [vpn connect];
    }
}

+ (void)turnOffVPN
{
    @autoreleasepool {        
        [DeviceConfigurator loadVPNPreferencesBundle];
        VPNConnectionStore *store = [objc_getClass("VPNConnectionStore") sharedInstance];
        unsigned long long grade = [store currentOnlyConnectionGrade];
        VPNConnection *vpn = [store currentConnectionWithGrade:grade];
        [vpn disconnect];
    }
}

+ (BOOL)isVPNEnabled
{
    @autoreleasepool {
        [DeviceConfigurator loadVPNPreferencesBundle];
        VPNConnectionStore *store = [objc_getClass("VPNConnectionStore") sharedInstance];
        unsigned long long grade = [store currentOnlyConnectionGrade];
        VPNConnection *vpn = [store currentConnectionWithGrade:grade];
        return [vpn connected];
    }
}

+ (void)takeScreenshot
{
/*    @autoreleasepool {
        [(SpringBoard *)[%c(SpringBoard) sharedApplication] takeScreenshot];
    }
*/
}

+ (NSString *)currentLanguage
{
    return [[NSLocale preferredLanguages] firstObject];
}

+ (NSString *)currentLocale
{
    return [[NSLocale currentLocale] localeIdentifier];
}
+ (NSString *)currentTimeZone
{
    return [[NSTimeZone systemTimeZone] name];
}

+ (void)setCurrentLanguage:(NSString *)language
{
  
    @autoreleasepool {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            @autoreleasepool {
                [DeviceConfigurator loadInternationalSettingsBundle];
                
                NSString *languageCode = InternationalSettingsExtractLanguageCode(language);
                [%c(InternationalSettingsController) setPreferredLanguages:@[languageCode]];
                if ([%c(InternationalSettingsController) respondsToSelector:@selector(setCurrentLanguage:)])
                {
                    [%c(InternationalSettingsController) setCurrentLanguage:languageCode];
                }
                else if ([%c(InternationalSettingsController) respondsToSelector:@selector(setLanguage:)])
                {
                    [%c(InternationalSettingsController) setLanguage:languageCode];
                }
            }
        });
    }
}

+ (InternationalSettingsController *)sharedInternationalSettingsController
{
    static InternationalSettingsController *isCtrl = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self loadInternationalSettingsBundle];
        isCtrl = [[objc_getClass("InternationalSettingsController") alloc] init];
    });
    return isCtrl;
}


+ (void)setCurrentLocale:(NSString *)locale
{
    @autoreleasepool {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            @autoreleasepool {
                [[DeviceConfigurator sharedInternationalSettingsController] setLocaleOnly:locale];
                [%c(InternationalSettingsController) syncPreferencesAndPostNotificationForLanguageChange];
            }
        });
    }
}

+ (PSGDateTimeController *)sharedPSGDateTimeController
{
    static PSGDateTimeController *dtCtrl = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self loadGeneralSettingsUIFramework];
        dtCtrl = [[objc_getClass("PSGDateTimeController") alloc] init];
    });
    return dtCtrl;
}

+ (void)setCurrentTimeZone:(NSString *)timeZoneName
{
    @autoreleasepool {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            @autoreleasepool {
                [DeviceConfigurator loadGeneralSettingsUIFramework];
                
                /*MSImageRef PreferencesBinary = MSGetImageByName("/System/Library/PrivateFrameworks/Preferences.framework/Preferences");
                if (PreferencesBinary)
                {
                    PSCityForTimeZone = make_sym_callable(MSFindSymbol(PreferencesBinary, "_PSCityForTimeZone"));
                }*/
                
                if (PSCityForTimeZone)
                {
                    CFTimeZoneRef timeZone = CFTimeZoneCreateWithName(kCFAllocatorDefault, (__bridge CFStringRef)timeZoneName, true);
                    
                    if (timeZone)
                    {
                        ALCity *cityObject = PSCityForTimeZone(timeZone);
                        if (cityObject)
                        {
                            PSGDateTimeController *dateTimeCtrl = [DeviceConfigurator sharedPSGDateTimeController];
                            [dateTimeCtrl reloadTimezone];
                            
                            PSSpecifier *autoTimeZoneSpecifierObject = nil;
                            for (PSSpecifier *specifierObject in [dateTimeCtrl specifiers]) {
                                if ([[specifierObject identifier] isEqualToString:@"SET_AUTOMATICALLY"])
                                {
                                    autoTimeZoneSpecifierObject = specifierObject;
                                    break;
                                }
                            }
                            
                            if (autoTimeZoneSpecifierObject)
                            {
                                [autoTimeZoneSpecifierObject performSetterWithValue:@(NO)];
                            }
                            
                            PSSpecifier *timeZoneSpecifierObject = [dateTimeCtrl timeZoneSpecifier];
                            if (timeZoneSpecifierObject)
                            {
                                [timeZoneSpecifierObject performSetterWithValue:cityObject];
                            }
                            
                            // this is where changes actually happen
                            [objc_getClass("PSTimeZoneController") setCurrentTimeZone:timeZoneName];
                        }
                        
                        CFRelease(timeZone);
                    }
                }
            }
        });
    }
}

@end