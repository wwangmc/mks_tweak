include $(THEOS)/makefiles/common.mk

TWEAK_NAME = pccontrol

# pccontrol_ARCHS =  arm64
pccontrol_FILES = $(wildcard *.x*) $(wildcard GCDWebServer/**/*.m)
pccontrol_CFLAGS = -Wno-error -Wno-module-import-in-extern-c -fobjc-arc
INCLUDE_PATHS := $(shell find GCDWebServer -type d)
pccontrol_CFLAGS += $(INCLUDE_PATHS:%=-I%)
pccontrol_FRAMEWORKS = UIKit AssetsLibrary CoreMedia  IOSurface
pccontrol_PRIVATE_FRAMEWORKS = IOKit
pccontrol_LIBRARIES = substrate


include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard;"
