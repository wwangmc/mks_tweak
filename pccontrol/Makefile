include $(THEOS)/makefiles/common.mk

TWEAK_NAME = pccontrol

# pccontrol_ARCHS =  arm64
# $(shell find LookinServer -name "*.m")
$(TWEAK_NAME)_FILES = $(wildcard *.x*) $(wildcard *.m) $(wildcard hid/*.m)
$(TWEAK_NAME)_CFLAGS = -Wno-error -Wno-module-import-in-extern-c -fobjc-arc

# 定义需要包含的目录（可自由增删）
SEARCH_DIRS := headers hid

# 自动查找所有目录并添加 -I 前缀
$(TWEAK_NAME)_CFLAGS += $(shell find $(SEARCH_DIRS) -type d -exec sh -c 'find {} -name "*.h" -print -quit | grep -q .' \; -print | sed 's/^/-I/')

$(TWEAK_NAME)_FRAMEWORKS = UIKit CoreGraphics CoreMedia Foundation IOKit QuartzCore
$(TWEAK_NAME)_PRIVATE_FRAMEWORKS = IOSurface
# $(TWEAK_NAME)_EXTRA_FRAMEWORKS = GCDWebServers
$(TWEAK_NAME)_LDFLAGS += -L./libs
$(TWEAK_NAME)_LDFLAGS += -lGCDWebServers

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard;"
