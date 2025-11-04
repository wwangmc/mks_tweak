#import <Foundation/Foundation.h>

#define LOG_FILE_NAME @"pccontrol.log"
#define LOG_DIRECTORY_NAME @"Logs"

typedef NS_ENUM(NSUInteger, LogLevel) {
    LogLevelDebug,
    LogLevelInfo,
    LogLevelWarning,
    LogLevelError
};

@interface FileLogger : NSObject

+ (instancetype)sharedLogger;

- (void)logWithLevel:(LogLevel)level message:(NSString *)message;
- (void)logDebug:(NSString *)format, ...;
- (void)logInfo:(NSString *)format, ...;
- (void)logWarning:(NSString *)format, ...;
- (void)logError:(NSString *)format, ...;

- (NSURL *)getLogFileURL;
- (NSString *)getLogFilePath;
- (void)clearLogs;

@end


@interface HybridLogger : NSObject

+ (instancetype)sharedLogger;

- (void)debug:(NSString *)message file:(const char *)file function:(const char *)function line:(int)line;
- (void)info:(NSString *)message;
- (void)error:(NSString *)message file:(const char *)file function:(const char *)function line:(int)line;

@end

// 便捷宏定义
#define LogDebug(format, ...) [[HybridLogger sharedLogger] debug:[NSString stringWithFormat:format, ##__VA_ARGS__] file:__FILE__ function:__FUNCTION__ line:__LINE__]
#define LogInfo(format, ...) [[HybridLogger sharedLogger] info:[NSString stringWithFormat:format, ##__VA_ARGS__]]
#define LogError(format, ...) [[HybridLogger sharedLogger] error:[NSString stringWithFormat:format, ##__VA_ARGS__] file:__FILE__ function:__FUNCTION__ line:__LINE__]
#define Log(format, ...) [[HybridLogger sharedLogger] debug:[NSString stringWithFormat:format, ##__VA_ARGS__] file:__FILE__ function:__FUNCTION__ line:__LINE__]
