// TODO: multiple client write back support


#include "SocketServer.h"
#include "Task.h"
#import <Foundation/Foundation.h>


CFSocketRef socketRef;
CFWriteStreamRef writeStreamRef = NULL;
CFReadStreamRef readStreamRef = NULL;
static NSMutableDictionary *socketClients = NULL;
void report_memory(void);


void socketServer()
{
    @autoreleasepool {
        // 创建一个支持 IPv6 的 CFSocket
        CFSocketRef _socket = CFSocketCreate(kCFAllocatorDefault, PF_INET6, SOCK_STREAM, IPPROTO_TCP, kCFSocketAcceptCallBack, TCPServerAcceptCallBack, NULL);
        
        if (_socket == NULL) {
            NSLog(@"### com.zjx.springboard: failed to create socket.");
            return;
        }
        
        UInt32 reused = 1;
        
        // 设置 SO_REUSEADDR 选项，允许重用地址
        setsockopt(CFSocketGetNative(_socket), SOL_SOCKET, SO_REUSEADDR, (const void *)&reused, sizeof(reused));
        
        // 使用 sockaddr_in6 结构体来支持 IPv6
        struct sockaddr_in6 Socketaddr;
        memset(&Socketaddr, 0, sizeof(Socketaddr));
        Socketaddr.sin6_len = sizeof(Socketaddr);
        Socketaddr.sin6_family = AF_INET6;
        
        // 绑定到所有可用的 IPv6 和 IPv4 地址
        Socketaddr.sin6_addr = in6addr_any;  // IN6ADDR_ANY_INIT
        Socketaddr.sin6_port = htons(PORT);  // 端口号
        
        // 创建 CFDataRef 用于设置套接字地址
        CFDataRef address = CFDataCreate(kCFAllocatorDefault, (UInt8 *)&Socketaddr, sizeof(Socketaddr));
        
        if (CFSocketSetAddress(_socket, address) != kCFSocketSuccess) {
            if (_socket) {
                CFRelease(_socket);
                //exit(1);
            }
            _socket = NULL;
            NSLog(@"### com.zjx.springboard: failed to bind socket.");
            return;
        }
        
        // 初始化客户端字典
        socketClients = [[NSMutableDictionary alloc] init];
        
        NSLog(@"### com.zjx.springboard: connection waiting");
        
        // 将 CFSocket 添加到当前的 RunLoop
        CFRunLoopRef cfrunLoop = CFRunLoopGetCurrent();
        CFRunLoopSourceRef source = CFSocketCreateRunLoopSource(kCFAllocatorDefault, _socket, 0);
        CFRunLoopAddSource(cfrunLoop, source, kCFRunLoopCommonModes);
        
        // 释放 RunLoopSource
        CFRelease(source);
        
        // 启动 RunLoop
        CFRunLoopRun();
    }
}
void sendHttpResponse(int statusCode, NSString *content, CFWriteStreamRef writeStream)
{
    // 构造状态行
    NSString *statusMessage = @"";
    switch (statusCode) {
        case 200:
            statusMessage = @"OK";
            break;
        case 400:
            statusMessage = @"Bad Request";
            break;
        case 404:
            statusMessage = @"Not Found";
            break;
        case 415:
            statusMessage = @"Unsupported Media Type";
            break;
        case 500:
            statusMessage = @"Internal Server Error";
            break;
        default:
            statusMessage = @"Unknown Status";
            break;
    }
    
    // 获取内容长度
    NSData *contentData = [content dataUsingEncoding:NSUTF8StringEncoding];
    NSUInteger contentLength = contentData.length;

    // 构造完整的 HTTP 响应字符串
    NSString *responseString = [NSString stringWithFormat:
        @"HTTP/1.1 %d %@\r\n"
        "Content-Type: text/plain\r\n"
        "Content-Length: %lu\r\n"
        "\r\n%@",
        statusCode, statusMessage, (unsigned long)contentLength, content];

    // 转为 C 字符串
    const char *responseCStr = [responseString UTF8String];

    // 写入到流
    if (writeStream) {
        CFWriteStreamWrite(writeStream, (const UInt8 *)responseCStr, strlen(responseCStr));
    }
}

static void handleHttpRequest(NSString *request, CFWriteStreamRef writeStream)
{
    @autoreleasepool{
        NSArray *lines = [request componentsSeparatedByString:@"\r\n"];
        NSString *requestLine = lines[0];
        NSArray *parts = [requestLine componentsSeparatedByString:@" "];
        if (parts.count > 2) {
            NSString *method = parts[0];  // 请求方法 (GET/POST)
            NSString *urlPath = parts[1]; // 请求路径

            if ([method isEqualToString:@"POST"]) {
                NSUInteger bodyIndex = [request rangeOfString:@"\r\n\r\n"].location;
                if (bodyIndex != NSNotFound && bodyIndex + 4 < request.length) {
                    NSString *body = [request substringFromIndex:bodyIndex + 4];

                    // 检查 Content-Type 是否为 JSON
                    BOOL isJson = NO;
                    for (NSString *line in lines) {
                        if ([line hasPrefix:@"Content-Type: application/json"]) {
                            isJson = YES;
                            break;
                        }
                    }
                    if (isJson) {
                        // 解析 JSON 数据
                        NSData *jsonData = [body dataUsingEncoding:NSUTF8StringEncoding];
                        NSError *error = nil;
                        NSDictionary *jsonObject = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
                        if (!error && [jsonObject isKindOfClass:[NSDictionary class]]) {
                            NSString *taskType = jsonObject[@"taskType"];
                            id content = jsonObject[@"content"]; // 可能是字符串或 JSON
                            if (taskType && content) {
                                   if ([content isKindOfClass:[NSDictionary class]]) {
                                        // content 是 JSON 格式
                                        HttpTask *task = [[HttpTask alloc] initWithTaskType:taskType 
                                                                                    content:nil 
                                                                                jsonContent:content];
                                        processHttpTask(task, writeStream);
                                    } else if ([content isKindOfClass:[NSString class]]) {
                                        // content 是普通字符串
                                        HttpTask *task = [[HttpTask alloc] initWithTaskType:taskType 
                                                                                    content:content 
                                                                                jsonContent:nil];
                                        processHttpTask(task, writeStream);
                                    } else {
                                        // content 类型不合法
                                        sendHttpResponse(400, @"Invalid content type", writeStream);
                                    }
                            } else {
                                sendHttpResponse(500, @"字段缺失", writeStream);
                            }
                        } else {
                            sendHttpResponse(400, @"Invalid JSON", writeStream);
                        }
                    } else {
                        sendHttpResponse(415, @"Unsupported Content", writeStream);
                    }
                }
            } else if ([method isEqualToString:@"GET"]) {
                sendHttpResponse(500,@"请求不支持，请使用Post",writeStream);
            }
        }
    }
}


static void readStream(CFReadStreamRef readStream, CFStreamEventType eventype, void * clientCallBackInfo) 
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @autoreleasepool{
            UInt8 readDataBuff[2048];
            memset(readDataBuff, 0, sizeof(readDataBuff));
            
            CFIndex hasRead = CFReadStreamRead(readStream, readDataBuff, sizeof(readDataBuff));

            if (hasRead > 0) {
                //don't know how it works, copied from https://www.educative.io/edpresso/splitting-a-string-using-strtok-in-c
                NSString *requestString = [[NSString alloc] initWithBytes:readDataBuff length:hasRead encoding:NSUTF8StringEncoding];

                // 找到对应的 writeStream
                CFWriteStreamRef writeStream = (CFWriteStreamRef)[socketClients[@((NSInteger)readStream)] longValue];
                if ([requestString hasPrefix:@"GET"] || [requestString hasPrefix:@"POST"]) {
                    // 调用 HTTP 处理逻辑
                    handleHttpRequest(requestString, writeStream);
                } else {
                    // 保留原有功能：处理普通数据任务
                    for (char *charSep = strtok((char *)readDataBuff, "\r\n"); charSep != NULL; charSep = strtok(NULL, "\r\n")) {
                        UInt8 *buff = (UInt8 *)charSep;
                        if (writeStream) {
                            processTask(buff, writeStream);
                        } else {
                            processTask(buff);
                        }
                    }
                }
            }
        }
    });

}

int notifyClient(UInt8* msg, CFWriteStreamRef client)
{
    int result;
    //dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        //NSLog(@"com.zjx.springboard: client: %x", client);
        if (client != 0)
        {
            result = CFWriteStreamWrite(client, msg, strlen((char*)msg));
        }
        result = -1;
    //});
    return result;
}

static void TCPServerAcceptCallBack(CFSocketRef socket, CFSocketCallBackType type, CFDataRef address, const void *data, void *info)
{
    if (kCFSocketAcceptCallBack == type) {
        
        CFSocketNativeHandle  nativeSocketHandle = *(CFSocketNativeHandle *)data;
        
        uint8_t name[SOCK_MAXADDRLEN];
        socklen_t namelen = sizeof(name);
        
        if (getpeername(nativeSocketHandle, (struct sockaddr *)name, &namelen) != 0) {
            
            NSLog(@"### com.zjx.springboard: ++++++++getpeername+++++++");
            
            exit(1);
        }
        
        struct sockaddr_in *addr_in = (struct sockaddr_in *)name;
        NSLog(@"### com.zjx.springboard: connection starts", inet_ntoa(addr_in-> sin_addr), addr_in->sin_port);
        
        readStreamRef = NULL;
        writeStreamRef = NULL;

        CFStreamCreatePairWithSocket(kCFAllocatorDefault, nativeSocketHandle, &readStreamRef, &writeStreamRef);
       
        if (readStreamRef && writeStreamRef) {
            CFReadStreamOpen(readStreamRef);
            CFWriteStreamOpen(writeStreamRef);
            
            CFStreamClientContext context = {0, NULL, NULL, NULL };

            if (!CFReadStreamSetClient(readStreamRef, kCFStreamEventHasBytesAvailable, readStream, &context)) {
                NSLog(@"### com.zjx.springboard: error 1");
                return;
            }
            
            CFReadStreamScheduleWithRunLoop(readStreamRef, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);

            [socketClients setObject:[NSNumber numberWithInteger:(NSInteger)writeStreamRef]
                 forKey:[NSNumber numberWithInteger:(NSInteger)readStreamRef]];
            //const char *str = "+++welcome++++\n";
            
            //CFWriteStreamWrite(writeStreamRef, (UInt8 *)str, strlen(str) + 1);	
        }
        else
        {
            close(nativeSocketHandle);
        }
		
    }
    
}
