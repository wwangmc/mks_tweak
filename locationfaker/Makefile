THEOS_DEVICE_IP = localhost
THEOS_DEVICE_PORT = 2222
DEBUG = 0
# FINALPACKAGE = 1

# 定义打包模式常量
ROOTFULL = 0
ROOTLESS = 1
ROOTHIDE = 2

# 默认使用 rootfull (0)，可通过命令行覆盖，如 `make TYPE=1` 选择 rootless
TYPE ?= $(ROOTLESS)

TARGET = iphone:clang:latest:15.0
ifeq ($(TYPE), $(ROOTLESS))
    THEOS_PACKAGE_SCHEME = rootless
else ifeq ($(TYPE), $(ROOTHIDE))
    THEOS_PACKAGE_SCHEME = roothide
else 
	TARGET = iphone:clang:latest:12.0
endif

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = locationfaker
locationfaker_FILES = $(wildcard *.x*)
locationfaker_FRAMEWORKS = CoreLocation

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "sbreload; killall -9 locationd"
include $(THEOS_MAKE_PATH)/aggregate.mk
