include $(THEOS)/makefiles/common.mk

TWEAK_NAME = pccontrol

pccontrol_ARCHS =  arm64
pccontrol_FILES = Tweak.xm SocketServer.xm Touch.xm Screen.xm SysExecutor.xm Task.xm Process.xm AlertBox.xm Common.xm Window.xm Toast.xm  UIKeyboard.xm DeviceInfo.xm TouchIndicator/TouchIndicatorWindow.xm TouchIndicator/TouchIndicatorView.xm TouchIndicator/TouchIndicatorCoordinateView.xm TouchIndicator/TouchIndicatorViewList.xm
pccontrol_CFLAGS = -Wno-error -Wno-module-import-in-extern-c -fobjc-arc
pccontrol_FRAMEWORKS = UIKit AssetsLibrary AVFoundation CoreMedia CoreVideo IOSurface IOMobileFramebuffer
pccontrol_PRIVATE_FRAMEWORKS = IOKit
pccontrol_LIBRARIES = substrate


include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "chown -R mobile:mobile /var/mobile/Library/ZXTouch && killall -9 SpringBoard;"
