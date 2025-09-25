include $(THEOS)/makefiles/common.mk

TOOL_NAME = keychain_clear

keychain_clear_FILES = $(wildcard *.mm)
keychain_clear_CFLAGS = -fno-objc-arc -Wno-error -Wno-module-import-in-extern-c
keychain_clear_CODESIGN_FLAGS = -Sentitlements.xml
keychain_clear_INSTALL_PATH = /usr/bin

include $(THEOS_MAKE_PATH)/tool.mk

SUBPROJECTS += kchelp
include $(THEOS_MAKE_PATH)/aggregate.mk
 
