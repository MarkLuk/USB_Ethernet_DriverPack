KDIR	        := /lib/modules/$(shell uname -r)/build
KERNEL_VERSION	:= $(shell uname -r)
PWD		        := $(shell pwd)
MODULE_NAME     := qf9700_android
obj-m		    := $(MODULE_NAME).o

ifneq (,$(filter $(SUBLEVEL),14 15 16 17 18 19 20 21))
MDIR = drivers/usb/net
endif

default: 
	@echo "Building QF9700_ANDROID USB2NET chip driver..."
	@make -C $(KDIR) SUBDIRS=$(PWD) modules

clean:
	-rm -f *.o *.ko .*.cmd .*.flags .mii.mod.o.d *.mod.c Module.symvers Module.markers modules.order version.h
	-rm -rf .tmp_versions

