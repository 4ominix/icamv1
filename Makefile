TARGET := iphone:clang:14.5:15.0
INSTALL_TARGET_PROCESSES = SpringBoard
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = icamv1

icamv1_FILES = Tweak.x VCamProxyDelegate.m
icamv1_CFLAGS = -fobjc-arc
icamv1_FRAMEWORKS = AVFoundation CoreMedia CoreGraphics UIKit CoreImage

include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += icamprefs
include $(THEOS_MAKE_PATH)/aggregate.mk
