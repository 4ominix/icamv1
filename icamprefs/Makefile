TARGET := iphone:clang:14.5:15.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = icamPrefs

icamPrefs_FILES = icamPrefsRootListController.m
icamPrefs_FRAMEWORKS = UIKit AVFoundation UniformTypeIdentifiers
icamPrefs_PRIVATE_FRAMEWORKS = Preferences
icamPrefs_INSTALL_PATH = /Library/PreferenceBundles
icamPrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk
