#include "Common.h"
#import <sys/utsname.h>
#import <rootless.h>


/*
Get device model name
*/
NSString* getDeviceName()
{
    struct utsname systemInfo;
    uname(&systemInfo);

    return [NSString stringWithCString:systemInfo.machine
                                encoding:NSUTF8StringEncoding];
}

/*
round up number by multiple of another number
*/
int roundUp(int numToRound, int multiple)
{
    if (multiple == 0)
        return numToRound;

    int remainder = numToRound % multiple;
    if (remainder == 0)
        return numToRound;

    return numToRound + multiple - remainder;
}

/*
Check whether current device is an iPad
*/
Boolean isIpad()
{
    if ( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad )
    {
        return YES;
    }
    return NO;
}

/*
generate a random integer between min and max.

ONLY POSITIVE NUMBER IS SUPPORTED!
*/
int getRandomNumberInt(int min, int max)
{
	min = abs(min);
	max = abs(max);

	if (max < min)
	{
		NSLog(@"### com.zjx.springboard: Max is less than min in getRandomNumberInt(). max: %d, min: %d", max, min);
	}
	return arc4random_uniform(abs(max-min)) + min;
}

/*
generate a random float between min and max.

ONLY POSITIVE NUMBER IS SUPPORTED!
ONLY SUPPORTS TO UP TO 5 DIGIT.
*/
float getRandomNumberFloat(float min, float max)
{
	min = abs(min);
	max = abs(max);

	if (max < min)
	{
		NSLog(@"### com.zjx.springboard: Max is less than min in getRandomNumberFloat(). max: %f, min: %f", max, min);
	}

	
	return getRandomNumberInt((int)(min*10000), (int)(max*10000))/10000.0f;
}

/**
Get document root of springboard
*/
NSString* getDocumentRoot()
{
    //NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [NSString stringWithFormat:ROOT_PATH_NS(@"/var/mobile/Library/%s/") ,@"ZXTouch"];
}
