# See mt76.h for possible channels
BUILD := DEBUG
CHANNEL := 1
VERSION := $(shell git describe --tags)

FLAGS := -Wall -Wpedantic -std=c++11 -MMD
DEBUG_FLAGS := -Og -g -DDEBUG
RELEASE_FLAGS := -O3
DEFINES := -DCHANNEL=$(CHANNEL) -DVERSION=\"$(VERSION)\"

CXXFLAGS += $(FLAGS) $($(BUILD)_FLAGS) $(DEFINES)
LDLIBS += -lstdc++ -lm -lusb-1.0 -lpthread
SOURCES := $(wildcard *.cpp) $(wildcard */*.cpp)
OBJECTS := $(patsubst %.cpp,%.o,$(SOURCES)) firmware.o
DEPENDENCIES := $(OBJECTS:.o=.d)

DRIVER_URL := http://download.windowsupdate.com/c/msdownload/update/driver/drvs/2017/07/1cd6a87c-623f-4407-a52d-c31be49e925c_e19f60808bdcbfbd3c3df6be3e71ffc52e43261e.cab
FIRMWARE_HASH := 48084d9fa53b9bb04358f3bb127b7495dc8f7bb0b3ca1437bd24ef2b6eabdf66

PREFIX := /usr/local
BINDIR := $(PREFIX)/bin
UDEVDIR := /lib/udev/rules.d
MODPDIR := /lib/modprobe.d
SYSDDIR := /lib/systemd/system

.PHONY: all
all: xow

xow: $(OBJECTS)

%.o: %.cpp
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c -o $@ $<

firmware.bin:
	curl -o driver.cab $(DRIVER_URL)
	cabextract -F FW_ACC_00U.bin driver.cab
	echo $(FIRMWARE_HASH) FW_ACC_00U.bin | sha256sum -c
	mv FW_ACC_00U.bin firmware.bin
	$(RM) driver.cab

firmware.o: firmware.bin
	$(LD) -r -b binary -o $@ $<

xow.service: xow.service.in
	sed 's|#BINDIR#|$(BINDIR)|' xow.service.in > xow.service

.PHONY: install
install: xow xow.service
	install -D -m 755 xow $(DESTDIR)$(BINDIR)/xow
	install -D -m 644 xow-udev.rules $(DESTDIR)$(UDEVDIR)/99-xow.rules
	install -D -m 644 xow-modprobe.conf $(DESTDIR)$(MODPDIR)/xow-blacklist.conf
	install -D -m 644 xow.service $(DESTDIR)$(SYSDDIR)/xow.service
	$(RM) xow.service

.PHONY: clean
clean:
	$(RM) xow $(OBJECTS) $(DEPENDENCIES)

-include $(DEPENDENCIES)
