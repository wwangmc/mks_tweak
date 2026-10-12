export ARCHS = arm64
include $(THEOS)/makefiles/common.mk

TOOL_NAME = appinst
appinst_FILES = appinst.m
appinst_CCFLAGS += -std=c++11 -stdlib=libc++ -fobjc-arc -include ./zip.h -I . -fvisibility=hidden -Wno-unused-property-ivar
appinst_CFLAGS += -fobjc-arc -include ./zip.h -I . -fvisibility=hidden -Wno-unused-property-ivar
appinst_FRAMEWORKS = Foundation ImageIO CoreGraphics
appinst_PRIVATE_FRAMEWORKS = MobileCoreServices
# appinst_LDFLAGS += $(THEOS)/lib/libzip.a
appinst_LIBRARIES = z lzma
appinst_LDFLAGS += -lbz2
appinst_LDFLAGS += -L./libs
appinst_LDFLAGS += -lzip
appinst_LDFLAGS += -lbz2

appinst_INSTALL_PATH = /usr/bin
appinst_CODESIGN_FLAGS = -Sappinst_entitlements.plist

include $(THEOS_MAKE_PATH)/tool.mk
