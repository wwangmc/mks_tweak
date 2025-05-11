#ifndef WEB_SERVER_H
#define WEB_SERVER_H
#include "GCDWebServer.h"
#include "GCDWebServerDataResponse.h"
#include "GCDWebServerErrorResponse.h"
#include "GCDWebServerDataRequest.h"
#define WEB_PORT 8080

void startWebServer();
void initHandle(GCDWebServer *webServer);
#endif

