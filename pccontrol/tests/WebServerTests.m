#import "WebServerSupport.h"
#import "ScreenshotStream.h"
#import "TestScreen.h"
#include <limits.h>
#include <math.h>

// Test doubles implement only the GCDWebServer APIs used by the production helpers.
// The bundled static library targets iOS and cannot execute on macOS.
static GCDWebServerProcessBlock registeredHandler;
static NSData *screenImage;
static NSUInteger captures;
static dispatch_block_t captureHook;

@implementation GCDWebServer
- (void)addHandlerForMethod:(NSString *)method path:(NSString *)path requestClass:(Class)requestClass
              processBlock:(GCDWebServerProcessBlock)block {
    registeredHandler = [block copy];
}
@end

@implementation GCDWebServerRequest
@end
@implementation GCDWebServerDataRequest
@end

@interface TestRequest : GCDWebServerDataRequest
@property(nonatomic, strong) NSData *bodyData;
@end
@implementation TestRequest
- (NSData *)data { return self.bodyData; }
@end

@interface GCDWebServerResponse ()
@property(nonatomic, strong) NSMutableDictionary *testHeaders;
@end
@implementation GCDWebServerResponse
+ (instancetype)response {
    GCDWebServerResponse *response = [self new];
    response.statusCode = 200;
    return response;
}
- (void)setValue:(NSString *)value forAdditionalHeader:(NSString *)header {
    if (!self.testHeaders) self.testHeaders = [NSMutableDictionary dictionary];
    self.testHeaders[header] = value;
}
- (void)close {}
@end

@interface GCDWebServerDataResponse ()
@property(nonatomic, strong) id testJSON;
@end
@implementation GCDWebServerDataResponse
@dynamic contentType;
+ (instancetype)responseWithJSONObject:(id)object {
    GCDWebServerDataResponse *response = [self response];
    response.testJSON = object;
    return response;
}
@end
@implementation GCDWebServerErrorResponse
+ (instancetype)responseWithClientError:(GCDWebServerClientErrorHTTPStatusCode)code message:(NSString *)format, ... {
    GCDWebServerErrorResponse *response = [self response];
    response.statusCode = code;
    return response;
}
+ (instancetype)responseWithServerError:(GCDWebServerServerErrorHTTPStatusCode)code message:(NSString *)format, ... {
    GCDWebServerErrorResponse *response = [self response];
    response.statusCode = code;
    return response;
}
@end

@interface GCDWebServerStreamedResponse ()
@property(nonatomic, copy) GCDWebServerAsyncStreamBlock testStream;
@end
@implementation GCDWebServerStreamedResponse
@dynamic contentType;
- (instancetype)initWithContentType:(NSString *)type asyncStreamBlock:(GCDWebServerAsyncStreamBlock)block {
    self = [super init];
    if (self) {
        self.contentType = type;
        self.testStream = block;
    }
    return self;
}
- (void)asyncReadDataWithCompletion:(GCDWebServerBodyReaderCompletionBlock)completion {
    self.testStream(completion);
}
@end

@implementation Screen
+ (NSData *)takeScreenshotWithQuality:(CGFloat)quality {
    captures++;
    if (captureHook) captureHook();
    return screenImage;
}
@end

static NSUInteger checks;
#define CHECK(condition) do { checks++; if (!(condition)) { NSLog(@"FAIL line %d: %s", __LINE__, #condition); exit(1); } } while (0)

static NSData *UTF8(NSString *string) { return [string dataUsingEncoding:NSUTF8StringEncoding]; }

static NSData *readFrame(MKSScreenshotStream *stream, NSError **error) {
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    __block NSData *frame;
    __block NSError *failure;
    [stream asyncReadDataWithCompletion:^(NSData *data, NSError *streamError) {
        frame = data;
        failure = streamError;
        dispatch_semaphore_signal(done);
    }];
    CHECK(dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC)) == 0);
    if (error) *error = failure;
    return frame;
}

static void testValidation(void) {
    NSError *error = nil;
    CHECK([MKSJSONDictionary(UTF8(@"{\"text\":\"中文\"}"), &error)[@"text"] isEqualToString:@"中文"]);
    CHECK(error == nil);
    for (NSString *invalid in @[@"", @"{", @"[]", @"null", @"123", @"\"text\""]) {
        error = nil;
        CHECK(MKSJSONDictionary(UTF8(invalid), &error) == nil);
        CHECK(error != nil);
        CHECK(MKSJSONDictionary(UTF8(invalid), NULL) == nil);
    }
    error = [NSError errorWithDomain:@"stale" code:1 userInfo:nil];
    CHECK(MKSJSONDictionary(UTF8(@"{}"), &error) != nil && error == nil);
    CHECK(MKSJSONDictionary(nil, &error) == nil && error != nil);
    CHECK(MKSString(@"text") != nil);
    CHECK(MKSString(@1) == nil && MKSString(NSNull.null) == nil && MKSString(@{}) == nil);
    double value = -1;
    CHECK(MKSReadNumber(@"0.3", 0, 1, &value) && value == 0.3);
    CHECK(MKSReadNumber(@0, 0, 1, &value) && value == 0);
    CHECK(MKSReadNumber(@1, 0, 1, &value) && value == 1);
    CHECK(MKSReadNumber(@"-90", -90, 90, &value) && value == -90);
    for (id invalid in @[@"abc", @"0.3x", @"", @"nan", @"inf", @"1e999", @(-0.1), @1.1, @(NAN), @(INFINITY), @YES, NSNull.null, @[], @{}]) {
        CHECK(!MKSReadNumber(invalid, 0, 1, NULL));
    }
    CHECK(!MKSReadNumber(nil, 0, 1, NULL));
    int integer;
    CHECK(MKSReadInteger(@"60", 1, 60, &integer) && integer == 60);
    CHECK(!MKSReadInteger(@"60.5", 1, 60, NULL));
    CHECK(!MKSReadInteger(@0, 1, 60, NULL));
    CHECK(!MKSReadInteger(@61, 1, 60, NULL));
    CHECK(MKSReadInteger(@(INT_MIN), INT_MIN, INT_MAX, &integer) && integer == INT_MIN);
    CHECK(MKSReadInteger(@(INT_MAX), INT_MIN, INT_MAX, &integer) && integer == INT_MAX);
    CHECK(!MKSReadInteger(@((double)INT_MAX + 1), INT_MIN, INT_MAX, NULL));
    CHECK(MKSIsStringArray(@[]) && MKSIsStringArray(@[@"com.example.app"]));
    CHECK(!MKSIsStringArray(@[@"com.example.app", NSNull.null]));
    CHECK(!MKSIsStringArray(@{}) && !MKSIsStringArray(@[@1]) && !MKSIsStringArray(@[@""]));
    for (NSString *action in @[@"down", @"move", @"up", @"tap"]) {
        CHECK(MKSIsValidTouch(@{@"x": @0, @"y": @100.5, @"type": action}));
    }
    CHECK(!MKSIsValidTouch((id)@[]));
    CHECK(!MKSIsValidTouch(@{@"x": @0, @"type": @"tap"}));
    CHECK(!MKSIsValidTouch(@{@"x": NSNull.null, @"y": @0, @"type": @"tap"}));
    CHECK(!MKSIsValidTouch(@{@"x": @0, @"y": @0, @"type": @1}));
    CHECK(!MKSIsValidTouch(@{@"x": @0, @"y": @0, @"type": @"unknown"}));
    CHECK(!MKSIsValidTouch(@{@"x": @(-1), @"y": @0, @"type": @"tap"}));
    CHECK([MKSShellQuote(@"a'b;$(id)") isEqualToString:@"'a'\\''b;$(id)'"]);
}

static void testResponses(void) {
    GCDWebServerDataResponse *success = staticSuccessResponse();
    CHECK(success.statusCode == 200);
    CHECK([success.testJSON[@"status"] isEqualToString:@"success"]);
    CHECK([success.testHeaders[@"Access-Control-Allow-Origin"] isEqualToString:@"*"]);
    CHECK([success.testHeaders[@"Access-Control-Allow-Methods"] isEqualToString:@"GET, POST, OPTIONS"]);
    CHECK(missingParamResponse().statusCode == 400);
    CHECK(jsonFormatErrorResponse().statusCode == 400);
    CHECK(MKSServerError(@"Failed").statusCode == 500);
    CHECK([MKSServerError(@"Failed").testHeaders[@"Access-Control-Allow-Origin"] isEqualToString:@"*"]);
    __block NSUInteger handlerCalls = 0;
    MKSAddJSONHandler([GCDWebServer new], @"/input", ^GCDWebServerResponse *(NSDictionary *body) {
        handlerCalls++;
        CHECK([body[@"text"] isEqualToString:@"hello"]);
        return staticSuccessResponse();
    });
    TestRequest *request = [TestRequest new];
    request.bodyData = UTF8(@"[]");
    CHECK(registeredHandler(request).statusCode == 400 && handlerCalls == 0);
    request.bodyData = UTF8(@"{");
    CHECK(registeredHandler(request).statusCode == 400 && handlerCalls == 0);
    request.bodyData = UTF8(@"{\"text\":\"hello\"}");
    CHECK(registeredHandler(request).statusCode == 200 && handlerCalls == 1);
}

static void testMainThreadDispatch(void) {
    __block BOOL ran = NO;
    MKSOnMainThread(^{
        CHECK(NSThread.isMainThread);
        ran = YES;
    });
    CHECK(ran);
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    __block NSThread *executionThread;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        MKSOnMainThread(^{ executionThread = NSThread.currentThread; });
        dispatch_semaphore_signal(done);
    });
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:2];
    while (dispatch_semaphore_wait(done, DISPATCH_TIME_NOW) != 0) {
        if (deadline.timeIntervalSinceNow < 0) CHECK(NO);
        [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
    CHECK(executionThread.isMainThread);
}

static void testStream(void) {
    screenImage = UTF8(@"fake-jpeg");
    captures = 0;
    MKSScreenshotStream *stream = [MKSScreenshotStream responseWithQuality:0.3 fps:20];
    CHECK([stream.contentType isEqualToString:@"multipart/x-mixed-replace; boundary=frame"]);
    NSError *error = nil;
    NSTimeInterval begin = NSProcessInfo.processInfo.systemUptime;
    NSData *frame = readFrame(stream, &error);
    CHECK(error == nil && captures == 1);
    CHECK([[[NSString alloc] initWithData:frame encoding:NSUTF8StringEncoding] isEqualToString:
        @"--frame\r\nContent-Type: image/jpeg\r\nContent-Length: 9\r\n\r\nfake-jpeg\r\n"]);
    CHECK(readFrame(stream, &error).length > 0 && error == nil && captures == 2);
    CHECK(NSProcessInfo.processInfo.systemUptime - begin >= 0.045);
    [stream close];
    CHECK(readFrame(stream, &error).length == 0 && error == nil && captures == 2);

    stream = [MKSScreenshotStream responseWithQuality:0.3 fps:1];
    CHECK(readFrame(stream, &error).length > 0);
    NSUInteger beforeClose = captures;
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    __block NSData *cancelledFrame;
    [stream asyncReadDataWithCompletion:^(NSData *data, NSError *failure) {
        cancelledFrame = data;
        dispatch_semaphore_signal(done);
    }];
    [stream close];
    CHECK(dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC)) == 0);
    CHECK(cancelledFrame != nil && cancelledFrame.length == 0 && captures == beforeClose);

    // A close racing with screenshot generation must discard that frame.
    stream = [MKSScreenshotStream responseWithQuality:0.3 fps:20];
    captureHook = ^{ [stream close]; };
    CHECK(readFrame(stream, &error).length == 0 && error == nil);
    captureHook = nil;

    screenImage = nil;
    stream = [MKSScreenshotStream responseWithQuality:0.3 fps:20];
    CHECK(readFrame(stream, &error) == nil && error.code == 500);
    [stream close];
}

int main(void) {
    @autoreleasepool {
        testValidation();
        testResponses();
        testMainThreadDispatch();
        testStream();
        printf("Passed %lu checks (JSON, validation, CORS, handler dispatch, stream framing, pacing and cancellation).\n", (unsigned long)checks);
    }
    return 0;
}
