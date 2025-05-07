THEOS_DEVICE_IP=localhost
THEOS_DEVICE_PORT=2222
ROOTLESS = 1
ifeq ($(ROOTLESS),1)
 THEOS_PACKAGE_SCHEME=rootless
endif
ifeq ($(THEOS_PACKAGE_SCHEME), rootless)
 TARGET = iphone:clang:latest:15.0
else
 TARGET = iphone:clang:latest:12.0
endif
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = appdelegate

appdelegate_FILES = Tweak.xm UIKeyboard.xm
appdelegate_CFLAGS = -Wno-error -Wno-module-import-in-extern-c -fobjc-arc

# appdelegate_ARCHS = arm64 armv7
appdelegate_FRAMEWORKS = UIKit
#appdelegate_CCFLAGS = -std=c++11

include $(THEOS_MAKE_PATH)/tweak.mk
