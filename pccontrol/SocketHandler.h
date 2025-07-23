#import <Foundation/Foundation.h>
#import "GCDWebsocketServerHandler.h"


@interface SocketHandler : GCDWebsocketServerHandler


- (void)stopTimer; // 停止定时器
@end
