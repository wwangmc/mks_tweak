include $(THEOS)/makefiles/common.mk

TWEAK_NAME = locationfaker
locationfaker_FILES = $(wildcard *.x*)
locationfaker_FRAMEWORKS = CoreLocation
$(TWEAK_NAME)_CFLAGS = -Wno-error -Wno-module-import-in-extern-c 

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "sbreload; killall -9 locationd"
include $(THEOS_MAKE_PATH)/aggregate.mk
