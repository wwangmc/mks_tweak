#import "SysExecutor.h"
#include <spawn.h>
#include <stdlib.h>
#import <UIKit/UIKit.h>
#import <rootless.h>

void sysExecute(NSString * command) 
{
    // 设置管道用于捕获输出
    int pipefd[2];
    pipe(pipefd);

    pid_t pid;
    posix_spawn_file_actions_t actions;
    posix_spawn_file_actions_init(&actions);

    // 将标准输出和错误输出重定向到管道
    posix_spawn_file_actions_adddup2(&actions, pipefd[1], STDOUT_FILENO);
    posix_spawn_file_actions_adddup2(&actions, pipefd[1], STDERR_FILENO);
    posix_spawn_file_actions_addclose(&actions, pipefd[0]);

    // 分割命令
    const char *argv[] = {ROOT_PATH("/bin/sh"), "-c", [command UTF8String], NULL};
    int status = posix_spawn(&pid, ROOT_PATH("/bin/sh"), &actions, NULL, (char *const *)argv, NULL);
    close(pipefd[1]);

    // 读取命令输出
    NSMutableData *outputData = [NSMutableData data];
    char buffer[1024];
    ssize_t bytesRead;
    while ((bytesRead = read(pipefd[0], buffer, sizeof(buffer) - 1)) > 0) {
        [outputData appendBytes:buffer length:bytesRead];
    }
    close(pipefd[0]);

    posix_spawn_file_actions_destroy(&actions);

    // 等待子进程结束
    if (status == 0) {
        int exitStatus;
        waitpid(pid, &exitStatus, 0);
    }

    // 将输出数据转换为字符串
    NSString *rawOutput = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];

    // 使用正则表达式过滤掉包含 "SubstituteLog" 前缀的日志行
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^.*SubstituteLog.*$" options:NSRegularExpressionAnchorsMatchLines error:&error];
    NSString *filteredOutput = rawOutput;
    if (regex && !error) {
        filteredOutput = [regex stringByReplacingMatchesInString:rawOutput options:0 range:NSMakeRange(0, rawOutput.length) withTemplate:@""];
    }

    // 移除所有空行
    NSArray *lines = [filteredOutput componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSPredicate *noEmptyLines = [NSPredicate predicateWithFormat:@"SELF != ''"];
    lines = [lines filteredArrayUsingPredicate:noEmptyLines];
    
    // 将非空行重新组合为单一字符串
    NSString *finalOutput = [lines componentsJoinedByString:@"\n"];
    
}

NSString *runCommand(NSString *command) {
    // 设置管道用于捕获输出
    int pipefd[2];
    pipe(pipefd);

    pid_t pid;
    posix_spawn_file_actions_t actions;
    posix_spawn_file_actions_init(&actions);

    // 将标准输出和错误输出重定向到管道
    posix_spawn_file_actions_adddup2(&actions, pipefd[1], STDOUT_FILENO);
    posix_spawn_file_actions_adddup2(&actions, pipefd[1], STDERR_FILENO);
    posix_spawn_file_actions_addclose(&actions, pipefd[0]);

    // 分割命令
    const char *argv[] = {ROOT_PATH("/bin/sh"), "-c", [command UTF8String], NULL};
    int status = posix_spawn(&pid, ROOT_PATH("/bin/sh"), &actions, NULL, (char *const *)argv, NULL);
    close(pipefd[1]);

    // 读取命令输出
    NSMutableData *outputData = [NSMutableData data];
    char buffer[1024];
    ssize_t bytesRead;
    while ((bytesRead = read(pipefd[0], buffer, sizeof(buffer) - 1)) > 0) {
        [outputData appendBytes:buffer length:bytesRead];
    }
    close(pipefd[0]);

    posix_spawn_file_actions_destroy(&actions);

    // 等待子进程结束
    if (status == 0) {
        int exitStatus;
        waitpid(pid, &exitStatus, 0);
    }

    // 将输出数据转换为字符串
    NSString *rawOutput = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];

    // 使用正则表达式过滤掉包含 "SubstituteLog" 前缀的日志行
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^.*SubstituteLog.*$" options:NSRegularExpressionAnchorsMatchLines error:&error];
    NSString *filteredOutput = rawOutput;
    if (regex && !error) {
        filteredOutput = [regex stringByReplacingMatchesInString:rawOutput options:0 range:NSMakeRange(0, rawOutput.length) withTemplate:@""];
    }

    // 移除所有空行
    NSArray *lines = [filteredOutput componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSPredicate *noEmptyLines = [NSPredicate predicateWithFormat:@"SELF != ''"];
    lines = [lines filteredArrayUsingPredicate:noEmptyLines];
    
    // 将非空行重新组合为单一字符串
    NSString *finalOutput = [lines componentsJoinedByString:@"\n"];
    
    return finalOutput;
}



NSString *getSandboxPathForBundleID(NSString *bundleID) {
    NSString *appSandboxPath = @"/private/var/mobile/Containers/Data/Application/";
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *directories = [fileManager contentsOfDirectoryAtPath:appSandboxPath error:nil];

    for (NSString *dir in directories) {
        NSString *appPath = [appSandboxPath stringByAppendingPathComponent:dir];
        NSString *metadataPath = [appPath stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"];

        if ([fileManager fileExistsAtPath:metadataPath]) {
            NSDictionary *metadata = [NSDictionary dictionaryWithContentsOfFile:metadataPath];
            NSString *metadataIdentifier = metadata[@"MCMMetadataIdentifier"];

            if ([metadataIdentifier isEqualToString:bundleID]) { // 精确匹配包名
                NSLog(@"Found sandbox path for bundle ID %@: %@", bundleID, appPath);
                return appPath; // 返回匹配的沙盒路径
            }
        }
    }
    NSLog(@"Sandbox path for bundle ID %@ not found.", bundleID);
    return nil;
}