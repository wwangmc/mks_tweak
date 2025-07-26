THEOS_DEVICE_IP = localhost
THEOS_DEVICE_PORT = 2222
DEBUG = 1
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

INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

SUBPROJECTS += pccontrol
SUBPROJECTS += appdelegate
SUBPROJECTS += StoreSwitcher2
SUBPROJECTS += locationfaker
include $(THEOS_MAKE_PATH)/aggregate.mk