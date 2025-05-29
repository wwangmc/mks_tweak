#ifndef PROCESS_H
#define PROCESS_H
#import <UIKit/UIKit.h>

#include <dlfcn.h>

int bringAppForeground(NSString *appIdentifier);
id getFrontMostApplication();
void rebootUserspace();

#endif