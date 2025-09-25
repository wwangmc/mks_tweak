
include $(THEOS)/makefiles/common.mk

TOOL_NAME = kchelp

kchelp_FILES = $(wildcard *.m)
kchelp_CFLAGS = -Wno-error -Wno-module-import-in-extern-c -fobjc-arc
kchelp_CODESIGN_FLAGS = -Sentitlements.plist
kchelp_INSTALL_PATH = /usr/local/bin

# 定义需要包含的目录（可自由增删）
# SEARCH_DIRS := GCDWebServer

# 自动查找所有目录并添加 -I 前缀
# $(TOOL_NAME)_CFLAGS += $(shell find $(SEARCH_DIRS) -type d -exec sh -c 'find {} -name "*.h" -print -quit | grep -q .' \; -print | sed 's/^/-I/')


include $(THEOS_MAKE_PATH)/tool.mk
