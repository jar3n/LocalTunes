ARCHS = armv7 arm64
TARGET = iphone:clang:10.3:6.0

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = LocalTunes

LocalTunes_FILES = $(wildcard Sources/*.m)
LocalTunes_FRAMEWORKS = UIKit Foundation CoreGraphics AVFoundation MediaPlayer
LocalTunes_CFLAGS = -fobjc-arc -fno-modules -Wno-deprecated-module-dot-map
LocalTunes_LDFLAGS = -Wl,-w
ADDITIONAL_CFLAGS = -fno-modules -Wno-deprecated-module-dot-map

include $(THEOS_MAKE_PATH)/application.mk
