#import <Foundation/Foundation.h>
#import <GCDWebServers/GCDWebsocketServerHandler.h>


@interface SocketHandler : GCDWebsocketServerHandler


- (void)stopTimer; // 停止定时器
- (void)handleTask:(NSString *)text;

@end
