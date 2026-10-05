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

int main(void) {
    @autoreleasepool {
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
        printf("Passed %lu command runner checks (stdout, stderr, large and invalid UTF-8 output, concurrency, spawn failures, descriptor cleanup).\n", (unsigned long)checks);
    }
    return 0;
}
