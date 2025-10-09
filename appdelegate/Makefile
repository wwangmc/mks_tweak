include $(THEOS)/makefiles/common.mk

TWEAK_NAME = appdelegate

appdelegate_FILES = Tweak.xm UIKeyboard.xm
appdelegate_CFLAGS = -Wno-error -Wno-module-import-in-extern-c -fobjc-arc

# appdelegate_ARCHS = arm64 armv7
appdelegate_FRAMEWORKS = UIKit AssetsLibrary CoreMedia
#appdelegate_CCFLAGS = -std=c++11
# $(TWEAK_NAME)_PRIVATE_FRAMEWORKS = IOKit IOSurface 

include $(THEOS_MAKE_PATH)/tweak.mk
