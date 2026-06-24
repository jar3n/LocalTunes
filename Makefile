ARCHS = armv7
TARGET = iphone:clang:9.3:6.0

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = LocalTunes

LocalTunes_FILES = $(wildcard Sources/*.m)
LocalTunes_FRAMEWORKS = UIKit Foundation CoreGraphics AVFoundation MediaPlayer
LocalTunes_CFLAGS = -fobjc-arc -fno-modules
LocalTunes_LDFLAGS = -Wl,-w
ADDITIONAL_CFLAGS = -fno-modules

include $(THEOS_MAKE_PATH)/application.mk
