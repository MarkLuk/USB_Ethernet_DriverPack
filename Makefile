################################################################################################################
#                                               VARIABLES                                                      #
################################################################################################################

#Package version
PKG_VER             := 0.1

#Package name
PKG_NAME            := USB_Ethernet_DriverPack.v$(PKG_VER).[Quiethinker].zip

#Kernel version
KERNEL_VER          := 8.6.5.7

# Setting path to toolchain
PATH                := $(shell pwd)/toolchain/prebuilt/bin:$(PATH)

#Kernel directory
ORIGIN_KERNEL_DIR   := original_kernel

#Kernel build directory
BUILD_DIR           := build

#Toolchain directory
TOOLCHAIN_DIR       := toolchain

#Patch directory
SOURCE_DIR          := src

#Tools directory    
TOOLS_DIR           := tools

#Deliverables directory
DELIVERY_DIR        := deliverables

#Kernel source link
KERNEL_SRC_LINK     := http://dlcdnet.asus.com/pub/ASUS/EeePAD/TF101/Eee_PAD_TF101_Kernel_Code_$(subst .,_,$(KERNEL_VER)).rar

#Setting cross compiler
CROSS_COMPILE       ?= arm-eabi-

#Cross compiler location
TOOLCHAIN_SRC       := http://nv-tegra.nvidia.com/gitweb/?p=android/platform/prebuilt.git\;a=snapshot\;h=7f069ba4b6c3271c94844624b34e9a3592c2c732\;sf=tgz

# Cross compiler location
CROSS_COMPILE_LOC   := `which $(CROSS_COMPILE)gcc`

# Cross compiler version
CROSS_COMPILE_VER   := `$(CROSS_COMPILE)gcc -v 2>&1 | grep "gcc version" | cut -d" " -f3`

#Check ccache support
CCACHE              := `which ccache`

#Enabling ccache support
ifneq "$(CCACHE)" ""
CROSS_COMPILE       := "ccache $(CROSS_COMPILE)"
endif

#Kernel compilation parameters
KERNEL_PARAMS       := -C $(BUILD_DIR)/kernel ARCH=arm CROSS_COMPILE=$(CROSS_COMPILE)


.PHONY              := all cross_compile internal_modules external_modules package

################################################################################################################
#                                              DEFAULT target                                                  #
################################################################################################################
all:  package

################################################################################################################
# Package building target                                                                                      #
################################################################################################################
package:    internal_modules external_modules
	@echo - Building ZIP package structure
	
	@mkdir -p $(BUILD_DIR)/package
	@cp -af $(SOURCE_DIR)/package/* $(BUILD_DIR)/package/

	@mkdir -p $(BUILD_DIR)/package/system/etc/init.d/
	@echo \#!/system/bin/sh                         >   $(BUILD_DIR)/package/system/etc/init.d/89usb_ethernet
	@echo " "                                       >>  $(BUILD_DIR)/package/system/etc/init.d/89usb_ethernet
	@echo \#USB Ethernet driver pack v$(PKG_VER)    >>  $(BUILD_DIR)/package/system/etc/init.d/89usb_ethernet

	@mkdir -p $(BUILD_DIR)/package/system/lib/modules/usb_ethernet
	@cd $(BUILD_DIR)/modules;                                                                                   \
        for f in *.ko;                                                                                          \
        do                                                                                                      \
            cp -af $$f                                          ../package/system/lib/modules/usb_ethernet/;    \
            echo insmod /system/lib/modules/usb_ethernet/$$f >> ../package/system/etc/init.d/89usb_ethernet;    \
        done;                                                                                                   \
    cd ../..
    
	@echo - Building ZIP package
	@cd $(BUILD_DIR)/package; zip -r $(PKG_NAME) ./*; cd ../..;
    
	@echo - Sign ZIP package
	@mkdir -p $(DELIVERY_DIR)     
	@java -jar $(TOOLS_DIR)/signapk.jar $(TOOLS_DIR)/testkey.x509.pem $(TOOLS_DIR)/testkey.pk8 $(BUILD_DIR)/package/$(PKG_NAME) $(DELIVERY_DIR)/$(PKG_NAME)
    
    
################################################################################################################
# Kernel modules building target                                                                               #
################################################################################################################
internal_modules:  cross_compile $(BUILD_DIR)/kernel
	@echo - Buildig internal modules
    
    # Updating build directory
	@cp -af $(SOURCE_DIR)/kernel/* $(BUILD_DIR)/kernel/

    # Configure the kernel
	@make AsusTF101_defconfig $(KERNEL_PARAMS)

    # Compiling the kernel
	@make modules $(KERNEL_PARAMS)

    # Extracting all modules
	@mkdir -p $(BUILD_DIR)/modules
	@find $(BUILD_DIR)/kernel/drivers/net/usb/ | grep -P ".ko$$" | xargs -i cp -af {} $(BUILD_DIR)/modules/


################################################################################################################
# Additional external non-kernel modules building target                                                       #
################################################################################################################
external_modules: cross_compile $(BUILD_DIR)/kernel
	@echo - Buildig external modules

	@mkdir -p $(BUILD_DIR)/drivers
	@cp -af $(SOURCE_DIR)/drivers/* $(BUILD_DIR)/drivers/

	@for driver in $(BUILD_DIR)/drivers/*;                                                                      \
    do                                                                                                          \
        make -C $$driver KDIR=$(shell pwd)/$(BUILD_DIR)/kernel ARCH=arm CROSS_COMPILE=$(CROSS_COMPILE);         \
        find $$driver | grep -P ".ko$$" | xargs -i cp -af {} $(BUILD_DIR)/modules/;                             \
    done;

################################################################################################################
# Original Kernel download target                                                                              #
################################################################################################################
$(ORIGIN_KERNEL_DIR):
	@echo - Downloading original kernel version $(KERNEL_VER)
	@wget $(KERNEL_SRC_LINK) -O kernel.rar
	
	@echo - Extracting kernel package
	@mkdir -p tmp
	@cd tmp; unrar e -yr ../kernel.rar; cd ..;
	@tar -zxf `ls tmp/*.tar.gz`  --directory=tmp
	
	@mv -f tmp/`ls tmp | head -n 1` $(ORIGIN_KERNEL_DIR)
	@rm -rf tmp kernel.rar;

################################################################################################################
# Build kernel directory target                                                                                #
################################################################################################################
$(BUILD_DIR)/kernel:   $(ORIGIN_KERNEL_DIR)
	@echo - Building kernel 'BUILD' directory
	@mkdir -p $(BUILD_DIR)/kernel
	@cp -af $(ORIGIN_KERNEL_DIR)/* $(BUILD_DIR)/kernel/

    
################################################################################################################
# Cross-compiler initialization                                                                                #
################################################################################################################
cross_compile:
	@if [ "$(CROSS_COMPILE_LOC)" = "" ] ;                                                   \
        then                                                                                \
            echo - Cross compiler was not found                         &&                  \
            wget $(TOOLCHAIN_SRC) -O toolchain.tgz                      &&                  \
            rm -rf $(TOOLCHAIN_DIR)                                     &&                  \
            mkdir -p $(TOOLCHAIN_DIR)                                   &&                  \
            tar -zxf  toolchain.tgz --directory=$(TOOLCHAIN_DIR)        &&                  \
            rm -rf toolchain.tgz ;                                                          \
        else                                                                                \
            echo - Cross compiler v$(CROSS_COMPILE_VER) was found at $(CROSS_COMPILE_LOC);  \
    fi

################################################################################################################
# Dependencies target                                                                                          #
################################################################################################################
dep:
	@sudo apt-get --yes install fakeroot build-essential crash kexec-tools makedumpfile kernel-wedge
	@sudo apt-get --yes build-dep linux
	@sudo apt-get --yes install git-core libncurses5 libncurses5-dev libelf-dev asciidoc binutils-dev unrar wget zip

################################################################################################################
# Total wipe target                                                                                            #
################################################################################################################
total_wipe:
	@rm -rf $(BUILD_DIR) $(ORIGIN_KERNEL_DIR) $(TOOLCHAIN_DIR) $(DELIVERY_DIR)

