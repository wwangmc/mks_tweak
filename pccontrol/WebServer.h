#ifndef WEB_SERVER_H
#define WEB_SERVER_H
#import "GCDWebsocketServer.h"


#define WEB_PORT 8081

void startWebServer();
void initHandle(GCDWebsocketServer *webServer);
#endif

