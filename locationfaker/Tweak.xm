#import <CoreLocation/CoreLocation.h>
#import <roothide.h>
%hook CLLocation

-(CLLocationCoordinate2D)coordinate {
    NSLog(@"locationGet");
    CLLocationCoordinate2D location;
    
    /* Open the configuration file */
    NSString *path = [jbroot(@"/var/mobile") stringByAppendingPathComponent:[@"com.csmk.locationfaker" stringByAppendingPathExtension:@"plist"]];
    NSDictionary *conf = [[NSDictionary alloc] initWithContentsOfFile:path];
    
    if (conf) {
        if ([conf objectForKey:@"Enabled"]) {
            if ([[conf objectForKey:@"Enabled"] boolValue] != TRUE) {
                CLLocationCoordinate2D original = %orig;
                [conf release];
                return original;
            }
        }
        if (!([conf objectForKey:@"Latitude"] && [conf objectForKey:@"Longitude"])) {
            NSLog(@"Missing Latitude/Longitude in configuration file %@\n", path);
        }
        else {
            location.latitude = [[conf objectForKey:@"Latitude"] doubleValue];
            location.longitude = [[conf objectForKey:@"Longitude"] doubleValue];
        }
    }
    // else {
    //     /* Use Apple's HQ as default location */
    //     NSDictionary *defaultConf = @{@"Latitude": @37.3349,
    //                                 @"Longitude": @-122.0093};
    //     [defaultConf writeToFile:path atomically:YES];
    //     location.latitude = [defaultConf[@"Latitude"] doubleValue];
    //     location.longitude = [defaultConf[@"Longitude"] doubleValue];
    // }
    
    if (conf) [conf release];
    
    return location;
}

%end

#import <execinfo.h>
#import <mach-o/dyld.h>
#include <substrate.h>



// since the tweak is injected to the applications, it should be hidden in case of unexpected behaviors
static char *(*dyld_get_image_name_old)(uint32_t index);
char *dyld_get_image_name_new(uint32_t index);

char *dyld_get_image_name_new(uint32_t index)
{
    char *imageName = dyld_get_image_name_old(index);
    if (strcmp(imageName, jbroot("/Library/MobileSubstrate/DynamicLibraries/locationfaker.dylib")) == 0)
	{
		return "/System/Library/PrivateFrameworks/CertUI.framework/CertUIA";
	}
    return imageName;
}

%ctor {
    MSHookFunction((void *)_dyld_get_image_name,(void *)dyld_get_image_name_new, (void **)&dyld_get_image_name_old);
}