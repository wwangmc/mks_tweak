#ifndef REQ_H
#define REQ_H
#import <UIKit/UIKit.h>

typedef void (^RequestCompletionHandler)(id jsonResponse, NSError *error);

void sendGETRequest(NSString *urlString, RequestCompletionHandler completion);


#endif