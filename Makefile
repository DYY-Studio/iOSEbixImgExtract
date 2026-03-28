TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = jp.co.yahoo.ebookjapan


include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ebookjapandumper

ebookjapandumper_FILES = Tweak.x
ebookjapandumper_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
