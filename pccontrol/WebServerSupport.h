#import <Foundation/Foundation.h>
#import <GCDWebServers/GCDWebServer.h>
#import <GCDWebServers/GCDWebServerDataRequest.h>
#import <GCDWebServers/GCDWebServerDataResponse.h>
#import <GCDWebServers/GCDWebServerErrorResponse.h>

#ifdef __cplusplus
extern "C" {
#endif

// Reject a non-object JSON root before a handler accesses dictionary keys.
NSDictionary *MKSJSONDictionary(NSData *data, NSError **error);
NSString *MKSString(id value);
BOOL MKSReadNumber(id value, double minimum, double maximum, double *result);
BOOL MKSReadInteger(id value, int minimum, int maximum, int *result);
BOOL MKSIsStringArray(id value);
BOOL MKSIsValidTouch(NSDictionary *body);
NSString *MKSShellQuote(NSString *value);
dispatch_queue_t MKSInputQueue(void);
void MKSOnMainThread(dispatch_block_t block);

GCDWebServerResponse *MKSApplyCORS(GCDWebServerResponse *response);
GCDWebServerDataResponse *dataResponse(NSDictionary *jsonData);
GCDWebServerDataResponse *staticSuccessResponse(void);
GCDWebServerErrorResponse *missingParamResponse(void);
GCDWebServerErrorResponse *jsonFormatErrorResponse(void);
GCDWebServerErrorResponse *MKSClientError(NSString *message);
GCDWebServerErrorResponse *MKSServerError(NSString *message);

typedef GCDWebServerResponse *(^MKSJSONHandler)(NSDictionary *body);
void MKSAddJSONHandler(GCDWebServer *server, NSString *path, MKSJSONHandler handler);

#ifdef __cplusplus
}
#endif
