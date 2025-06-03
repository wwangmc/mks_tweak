THEOS_DEVICE_IP=localhost
THEOS_DEVICE_PORT=2222
ROOTLESS = 1
DEBUG = 0
# FINALPACKAGE=1

ifeq ($(ROOTLESS),1)
 THEOS_PACKAGE_SCHEME=rootless
endif
ifeq ($(THEOS_PACKAGE_SCHEME), rootless)
 TARGET = iphone:clang:latest:15.0
else
 TARGET = iphone:clang:latest:12.0
endif
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk


SUBPROJECTS += pccontrol
SUBPROJECTS += appdelegate
SUBPROJECTS += StoreSwitcher2
include $(THEOS_MAKE_PATH)/aggregate.mk
