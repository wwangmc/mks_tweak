#import "SysExecutor.h"
#import <dispatch/dispatch.h>
#include <fcntl.h>
#include <unistd.h>

static NSUInteger checks;
#define CHECK(condition) do { checks++; if (!(condition)) { NSLog(@"FAIL line %d: %s", __LINE__, #condition); exit(1); } } while (0)

static NSUInteger openDescriptors(void) {
    NSUInteger count = 0;
    for (int fd = 0; fd < 256; fd++) if (fcntl(fd, F_GETFD) >= 0) count++;
    return count;
}

static void testReadPlist(void) {
    CHECK(readPlistAtPath(nil) == nil);
    CHECK(readPlistAtPath(@"") == nil);
    CHECK(readPlistAtPath((id)NSNull.null) == nil);
    NSString *directory = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    CHECK([[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil]);
    NSString *path = [directory stringByAppendingPathComponent:@"test.plist"];
    CHECK(readPlistAtPath(path) == nil);
    NSDictionary *expected = @{@"text": @"中文", @"number": @3, @"nested": @{@"enabled": @YES}};
    CHECK([expected writeToFile:path atomically:YES]);
    CHECK([readPlistAtPath(path) isEqualToDictionary:expected]);
    NSData *binary = [NSPropertyListSerialization dataWithPropertyList:expected format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil];
    CHECK([binary writeToFile:path atomically:YES]);
    CHECK([readPlistAtPath(path) isEqualToDictionary:expected]);
    CHECK([@[@"not-a-dictionary"] writeToFile:path atomically:YES]);
    CHECK(readPlistAtPath(path) == nil);
    CHECK([[@"invalid plist" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:path atomically:YES]);
    CHECK(readPlistAtPath(path) == nil);
    CHECK([[NSFileManager defaultManager] removeItemAtPath:directory error:nil]);
}

int main(void) {
    @autoreleasepool {
        testReadPlist();
        CHECK(runCommand(nil) == nil);
        CHECK(runCommand(@"") == nil);
        CHECK([runCommand(@"printf hello") isEqualToString:@"hello"]);
        CHECK([runCommand(@"printf error >&2") isEqualToString:@"error"]);
        CHECK([runCommand(@"printf 'first\\nSubstituteLog noisy\\n\\nlast\\n'") isEqualToString:@"first\nlast"]);
        CHECK([runCommand(@"printf failed; exit 7") isEqualToString:@"failed"]);
        CHECK([runCommand(@"printf '\\377'") isEqualToString:@"ÿ"]);
        CHECK([runCommand(@"awk 'BEGIN { for (i=0; i<20000; i++) printf \"x\" }'") length] == 20000);
        CHECK([runCommand(@"true") isEqualToString:@""]);

        // Spawn overlap checks for leaked pipe ends or unwanted descriptor inheritance.
        dispatch_group_t group = dispatch_group_create();
        __block NSString *slowOutput;
        __block NSString *fastOutput;
        dispatch_group_async(group, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
            slowOutput = runCommand(@"sleep 1; printf slow");
        });
        dispatch_group_async(group, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
            fastOutput = runCommand(@"printf fast");
        });
        CHECK(dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) == 0);
        CHECK([slowOutput isEqualToString:@"slow"] && [fastOutput isEqualToString:@"fast"]);

        NSUInteger before = openDescriptors();
        for (int i = 0; i < 20; i++) CHECK([runCommand(@"printf ok") isEqualToString:@"ok"]);
        CHECK(openDescriptors() == before);
        setenv("MKS_TEST_ROOTHELP", "/nonexistent/mks-roothelp-test", 1);
        for (int i = 0; i < 3; i++) CHECK(runCommand(@"printf hello") == nil);
        CHECK(openDescriptors() == before);
        printf("Passed %lu plist and command runner checks (XML/binary plist, invalid paths and roots, output, concurrency, spawn failures, descriptor cleanup).\n", (unsigned long)checks);
    }
    return 0;
}
