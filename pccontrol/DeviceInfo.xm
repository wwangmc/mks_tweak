#include "DeviceInfo.h"
#include "Screen.h"
#import <sys/utsname.h>
static NSString* modelName()
{
    struct utsname systemInfo;
    uname(&systemInfo);

    return [NSString stringWithCString:systemInfo.machine
                                encoding:NSUTF8StringEncoding];
}


NSString *getDeviceInfoFromRawData(int eventData, NSError **error)
{
    if (eventData == DEVICE_INFO_TASK_GET_SCREEN_SIZE)
    {
        return [NSString stringWithFormat:@"%f;;%f", [Screen getScreenWidth], [Screen getScreenHeight]];
    }
    else if (eventData == DEVICE_INFO_TASK_GET_SCREEN_ORIENTATION)
    {
        return [NSString stringWithFormat:@"%d", [Screen getScreenOrientation]];
    }
    else if (eventData == DEVICE_INFO_TASK_GET_SCREEN_SCALE)
    {
        return [NSString stringWithFormat:@"%f", [Screen getScale]];
    }
    else if (eventData == DEVICE_INFO_TASK_GET_DEVICE_INFO)
    {
        return [NSString stringWithFormat:@"%@;;%@;;%@;;%@;;%@", 
                                        [[UIDevice currentDevice] name], 
                                        [[UIDevice currentDevice] systemName], 
                                        [[UIDevice currentDevice] systemVersion], 
                                        modelName(), 
                                        [[UIDevice currentDevice] identifierForVendor]];
    }
    else if (eventData == DEVICE_INFO_TASK_GET_BATTERY_INFO)
    {
        UIDevice *myDevice = [UIDevice currentDevice];
        [myDevice setBatteryMonitoringEnabled:YES];

        int state = [myDevice batteryState];
        double batLeft = (float)[myDevice batteryLevel] * 100;


        return [NSString stringWithFormat:@"%d;;%f", 
                                state, 
                                batLeft];
    }
    else
    {
        *error = [NSError errorWithDomain:@"com.zjx.zxtouchsp" code:999 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"-1;;Unknown device info task type. The task you provide: %d\r\n", eventData]}];
        return @"";
    }
}