#import "FileLogger.h"
#import <os/log.h>

#define GetLogDirectory() \
[[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] \
stringByAppendingPathComponent:LOG_DIRECTORY_NAME]
#define GetLogFilePath() \
[GetLogDirectory() stringByAppendingPathComponent:LOG_FILE_NAME]

@implementation FileLogger {
    NSFileHandle *_fileHandle;
    NSDateFormatter *_dateFormatter;
    dispatch_queue_t _logQueue;
}

+ (instancetype)sharedLogger {
    static FileLogger *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _logQueue = dispatch_queue_create("com.yourapp.logger", DISPATCH_QUEUE_SERIAL);
        
        // 设置日期格式
        _dateFormatter = [[NSDateFormatter alloc] init];
        [_dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
        
        // 创建日志目录
        NSString *logDirectory = GetLogDirectory();

        if (![[NSFileManager defaultManager] fileExistsAtPath:logDirectory]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:logDirectory
                                      withIntermediateDirectories:YES
                                                       attributes:nil
                                                            error:nil];
        }
        
        // 创建日志文件
        NSString *logFilePath = GetLogFilePath();
        
        if (![[NSFileManager defaultManager] fileExistsAtPath:logFilePath]) {
            [[NSFileManager defaultManager] createFileAtPath:logFilePath
                                                    contents:nil
                                                  attributes:nil];
        }
        
        // 打开文件句柄
        _fileHandle = [NSFileHandle fileHandleForWritingAtPath:logFilePath];
        if (_fileHandle) {
            [_fileHandle seekToEndOfFile];
        }
    }
    return self;
}

- (void)logWithLevel:(LogLevel)level message:(NSString *)message {
    dispatch_async(_logQueue, ^{
        NSString *levelString = [self stringFromLogLevel:level];
        NSString *timestamp = [_dateFormatter stringFromDate:[NSDate date]];
        NSString *logMessage = [NSString stringWithFormat:@"[%@] [%@] %@\n", timestamp, levelString, message];
        
        // 写入文件
        if (self->_fileHandle) {
            [self->_fileHandle writeData:[logMessage dataUsingEncoding:NSUTF8StringEncoding]];
        }
        
        // 同时输出到控制台（调试模式）
#ifdef DEBUG
        NSLog(@"%@", [logMessage stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]]);
#endif
    });
}

// 便捷方法
- (void)logDebug:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    [self logWithLevel:LogLevelDebug message:message];
}

- (void)logInfo:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    [self logWithLevel:LogLevelInfo message:message];
}

- (void)logWarning:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    [self logWithLevel:LogLevelWarning message:message];
}

- (void)logError:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    [self logWithLevel:LogLevelError message:message];
}

- (NSString *)stringFromLogLevel:(LogLevel)level {
    switch (level) {
        case LogLevelDebug: return @"DEBUG";
        case LogLevelInfo: return @"INFO";
        case LogLevelWarning: return @"WARNING";
        case LogLevelError: return @"ERROR";
        default: return @"UNKNOWN";
    }
}

- (NSURL *)getLogFileURL {
    return [NSURL fileURLWithPath:GetLogFilePath()];
}

- (NSString *)getLogFilePath {
    return GetLogFilePath();
}

- (void)clearLogs {
    dispatch_async(_logQueue, ^{
        if (self->_fileHandle) {
            [self->_fileHandle closeFile];
            self->_fileHandle = nil;
        }
        
        NSString *logFilePath = [self getLogFilePath];
        [[NSFileManager defaultManager] removeItemAtPath:logFilePath error:nil];
        
        // 重新创建文件
        [[NSFileManager defaultManager] createFileAtPath:logFilePath
                                                contents:nil
                                              attributes:nil];
        
        self->_fileHandle = [NSFileHandle fileHandleForWritingAtPath:logFilePath];
        [self->_fileHandle seekToEndOfFile];
    });
}

- (void)dealloc {
    [_fileHandle closeFile];
}

@end

@implementation HybridLogger {
    os_log_t _systemLog;
}

+ (instancetype)sharedLogger {
    static HybridLogger *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _systemLog = os_log_create("com.yourapp", "application");
    }
    return self;
}

- (void)debug:(NSString *)message file:(const char *)file function:(const char *)function line:(int)line {
    // 输出到系统日志
    os_log_debug(_systemLog, "%{public}@", message);
    
    // 输出到文件（包含更多上下文信息）
    NSString *fileName = [[NSString stringWithUTF8String:file] lastPathComponent];
    NSString *fileMessage = [NSString stringWithFormat:@"[%@:%d %s] %@", fileName, line, function, message];
    [[FileLogger sharedLogger] logWithLevel:LogLevelDebug message:fileMessage];
}

- (void)info:(NSString *)message {
    os_log_info(_systemLog, "%{public}@", message);
    [[FileLogger sharedLogger] logWithLevel:LogLevelInfo message:message];
}

- (void)error:(NSString *)message file:(const char *)file function:(const char *)function line:(int)line {
    os_log_error(_systemLog, "%{public}@", message);
    
    NSString *fileName = [[NSString stringWithUTF8String:file] lastPathComponent];
    NSString *fileMessage = [NSString stringWithFormat:@"[%@:%d %s] %@", fileName, line, function, message];
    [[FileLogger sharedLogger] logWithLevel:LogLevelError message:fileMessage];
}

@end
