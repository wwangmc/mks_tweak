#import "WebServerSupport.h"
#import <CoreFoundation/CoreFoundation.h>
#include <math.h>
#include <float.h>

NSDictionary *MKSJSONDictionary(NSData *data, NSError **error) {
    if (error) *error = nil;
    id body = data.length ? [NSJSONSerialization JSONObjectWithData:data options:0 error:error] : nil;
    if (![body isKindOfClass:[NSDictionary class]]) {
        if (error && !*error) {
            *error = [NSError errorWithDomain:@"com.csmk.webserver" code:400
                                    userInfo:@{NSLocalizedDescriptionKey: @"Expected a JSON object"}];
        }
        return nil;
    }
    return body;
}

NSString *MKSString(id value) {
    return [value isKindOfClass:[NSString class]] ? value : nil;
}

BOOL MKSReadNumber(id value, double minimum, double maximum, double *result) {
    double number;
    if ([value isKindOfClass:[NSNumber class]]) {
        if (CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID()) return NO;
        number = [value doubleValue];
    } else if ([value isKindOfClass:[NSString class]] && [value length]) {
        NSScanner *scanner = [NSScanner scannerWithString:value];
        scanner.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        if (![scanner scanDouble:&number] || !scanner.isAtEnd) return NO;
    } else {
        return NO;
    }
    if (!isfinite(number) || number < minimum || number > maximum) return NO;
    if (result) *result = number;
    return YES;
}

BOOL MKSReadInteger(id value, int minimum, int maximum, int *result) {
    double number;
    if (!MKSReadNumber(value, minimum, maximum, &number) || trunc(number) != number) return NO;
    if (result) *result = (int)number;
    return YES;
}

BOOL MKSIsStringArray(id value) {
    if (![value isKindOfClass:[NSArray class]]) return NO;
    for (id item in value) {
        if (!MKSString(item).length) return NO;
    }
    return YES;
}

BOOL MKSIsValidTouch(NSDictionary *body) {
    if (![body isKindOfClass:[NSDictionary class]]) return NO;
    NSString *type = MKSString(body[@"type"]);
    return MKSReadNumber(body[@"x"], 0, FLT_MAX, NULL) &&
           MKSReadNumber(body[@"y"], 0, FLT_MAX, NULL) &&
           ([type isEqualToString:@"down"] || [type isEqualToString:@"move"] ||
            [type isEqualToString:@"up"] || [type isEqualToString:@"tap"]);
}

NSString *MKSShellQuote(NSString *value) {
    return [NSString stringWithFormat:@"'%@'", [value stringByReplacingOccurrencesOfString:@"'" withString:@"'\\''"]];
}

dispatch_queue_t MKSInputQueue(void) {
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("com.csmk.input", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

void MKSOnMainThread(dispatch_block_t block) {
    if ([NSThread isMainThread]) block();
    else dispatch_sync(dispatch_get_main_queue(), block);
}

GCDWebServerResponse *MKSApplyCORS(GCDWebServerResponse *response) {
    [response setValue:@"*" forAdditionalHeader:@"Access-Control-Allow-Origin"];
    [response setValue:@"Content-Type" forAdditionalHeader:@"Access-Control-Allow-Headers"];
    [response setValue:@"GET, POST, OPTIONS" forAdditionalHeader:@"Access-Control-Allow-Methods"];
    return response;
}

GCDWebServerDataResponse *dataResponse(NSDictionary *jsonData) {
    GCDWebServerDataResponse *response = [GCDWebServerDataResponse responseWithJSONObject:jsonData];
    MKSApplyCORS(response);
    return response;
}

GCDWebServerDataResponse *staticSuccessResponse(void) {
    return dataResponse(@{@"status": @"success"});
}

GCDWebServerErrorResponse *MKSClientError(NSString *message) {
    GCDWebServerErrorResponse *response = [GCDWebServerErrorResponse
        responseWithClientError:kGCDWebServerHTTPStatusCode_BadRequest message:@"%@", message];
    MKSApplyCORS(response);
    return response;
}

GCDWebServerErrorResponse *MKSServerError(NSString *message) {
    GCDWebServerErrorResponse *response = [GCDWebServerErrorResponse
        responseWithServerError:kGCDWebServerHTTPStatusCode_InternalServerError message:@"%@", message];
    MKSApplyCORS(response);
    return response;
}

GCDWebServerErrorResponse *missingParamResponse(void) {
    return MKSClientError(@"Missing or invalid parameter");
}

GCDWebServerErrorResponse *jsonFormatErrorResponse(void) {
    return MKSClientError(@"Invalid JSON: expected an object");
}

void MKSAddJSONHandler(GCDWebServer *server, NSString *path, MKSJSONHandler handler) {
    [server addHandlerForMethod:@"POST" path:path requestClass:[GCDWebServerDataRequest class]
                  processBlock:^GCDWebServerResponse *(GCDWebServerDataRequest *request) {
        NSError *error = nil;
        NSDictionary *body = MKSJSONDictionary(request.data, &error);
        return body ? handler(body) : jsonFormatErrorResponse();
    }];
}
