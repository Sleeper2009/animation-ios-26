ifndef THEOS
$(error THEOS is not set)
endif

TARGET := iphone:clang:16.5:14.0
INSTALL_TARGET_PROCESSES = backboardd
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = LiquidMorph

LiquidMorph_FILES = Tweak.xm
LiquidMorph_CFLAGS = -fobjc-arc
LiquidMorph_FRAMEWORKS = UIKit

include $(THEOS_MAKE_PATH)/tweak.mk
