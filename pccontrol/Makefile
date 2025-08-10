include $(THEOS)/makefiles/common.mk

TWEAK_NAME = pccontrol

# pccontrol_ARCHS =  arm64
pccontrol_FILES = $(wildcard *.x*) $(wildcard GCDWebServer/**/*.m) $(wildcard screen/*.m)
pccontrol_CFLAGS = -Wno-error -Wno-module-import-in-extern-c -fobjc-arc

# 定义需要包含的目录（可自由增删）
SEARCH_DIRS := GCDWebServer

# 自动查找所有目录并添加 -I 前缀
pccontrol_CFLAGS += $(shell find $(SEARCH_DIRS) -type d | sed 's/^/-I/')

# HEADER_PATHS := screen
# pccontrol_CFLAGS += $(HEADER_PATHS:%=-I%)
# pccontrol_CFLAGS += -include screen-prefix.pch
pccontrol_FRAMEWORKS = UIKit AssetsLibrary CoreMedia
pccontrol_PRIVATE_FRAMEWORKS = IOKit IOSurface
pccontrol_LIBRARIES = substrate


include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard;"
