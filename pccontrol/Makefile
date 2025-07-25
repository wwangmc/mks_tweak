include $(THEOS)/makefiles/common.mk

TWEAK_NAME = pccontrol

# pccontrol_ARCHS =  arm64
pccontrol_FILES = $(wildcard *.x*) $(wildcard GCDWebServer/**/*.m) $(wildcard screen/*.m)
pccontrol_CFLAGS = -Wno-error -Wno-module-import-in-extern-c -fobjc-arc

INCLUDE_PATHS := $(shell find GCDWebServer -type d)
pccontrol_CFLAGS += $(INCLUDE_PATHS:%=-I%)

HEADER_PATHS := screen
pccontrol_CFLAGS += $(HEADER_PATHS:%=-I%)
# pccontrol_CFLAGS += -include screen-prefix.pch
pccontrol_FRAMEWORKS = UIKit AssetsLibrary CoreMedia  
pccontrol_PRIVATE_FRAMEWORKS = IOKit IOSurface
pccontrol_LIBRARIES = substrate


include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard;"
