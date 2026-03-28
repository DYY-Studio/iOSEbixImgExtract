TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = jp.co.yahoo.ebookjapan


include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ebookjapandumper

ebookjapandumper_FILES = Tweak.x $(wildcard SSZipArchive/*.m) $(wildcard SSZipArchive/minizip/*.c) $(wildcard SSZipArchive/minizip/compat/*.c)
ebookjapandumper_CFLAGS = -fobjc-arc -ObjC -DHAVE_ZLIB -DHAVE_WZAES -DZLIB_COMPAT -ISSZipArchive -ISSZipArchive/minizip -ISSZipArchive/minizip/compat
ebookjapandumper_LDFLAGS += -undefined dynamic_lookup
ebookjapandumper_LIBRARIES = z iconv
ebookjapandumper_FRAMEWORKS = UIKit UniformTypeIdentifiers Security

include $(THEOS_MAKE_PATH)/tweak.mk
