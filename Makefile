ARCHS = armv7
TARGET = iphone:clang:9.3:6.0

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = LocalTunes

LocalTunes_FILES = $(wildcard Sources/*.m)
LocalTunes_FRAMEWORKS = UIKit Foundation CoreGraphics AVFoundation MediaPlayer
LocalTunes_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/application.mk
