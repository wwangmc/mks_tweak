#include <stdio.h>
#include "TSUtil.h"
#include <roothide.h>
int main(int argc, char *argv[], char *envp[]) {
    NSArray *arguments = [[NSProcessInfo processInfo] arguments];
	NSString *kc = jbroot(@"/usr/bin/keychain_clear");

	for(int i= 0; i<arguments.count;i++)
	{
		NSString * item = arguments[i];
		if([item isEqualToString:@"-l"])
		{
			return spawnRoot(kc,@[@"-l"], nil, nil);
		}
		if([item isEqualToString:@"-r"])
		{
			int index = i+1;
			if(index<arguments.count)
			{
				if([arguments[index] isEqualToString:@"-a"])
				{
					// deleteAllKeychainObjects();
					return spawnRoot(kc,@[@"-r",@"-a"], nil, nil);

				}else if([arguments[index] isEqualToString:@"-g"])
				{
					index = index+1;
					if(index<arguments.count)
					{
						return spawnRoot(kc,@[@"-r",@"-g",arguments[index]], nil, nil);

					}
				}
			}
		}
	}
	return 0;
}
