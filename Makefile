DEBUG = 0

include $(THEOS)/makefiles/common.mk


SUBPROJECTS += appdelegate
SUBPROJECTS += pccontrol
# SUBPROJECTS += ModernUI
include $(THEOS_MAKE_PATH)/aggregate.mk
