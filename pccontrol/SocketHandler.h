#import <Foundation/Foundation.h>
#import <GCDWebServers/GCDWebsocketServerHandler.h>


@interface SocketHandler : GCDWebsocketServerHandler


- (void)handleTask:(NSString *)text;

@end
