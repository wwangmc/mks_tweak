#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/mks-webserver-tests.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT HUP INT TERM
xcrun clang -fobjc-arc -fblocks -Wall -Wextra -Wno-unused-parameter \
    -Wno-incomplete-implementation -Wno-protocol \
    -I. -Iheaders -include tests/TestScreen.h \
    WebServerSupport.m ScreenshotStream.m tests/WebServerTests.m \
    -framework Foundation -o "$test_dir/webserver-tests"
"$test_dir/webserver-tests"
cat > "$test_dir/roothelp" <<'HELPER'
#!/bin/sh
exec /bin/sh -c "$1"
HELPER
chmod +x "$test_dir/roothelp"
xcrun clang++ -x objective-c++ -fobjc-arc -fblocks -Wall -Wextra \
    -I. -Itests/stubs SysExecutor.xm tests/SysExecutorTests.mm \
    -framework Foundation -o "$test_dir/executor-tests"
MKS_TEST_ROOTHELP="$test_dir/roothelp" "$test_dir/executor-tests"
