#!/bin/bash
# boot partition 32MB, vfat
# root partition 1GB, ext4


source general.sh

downloadKernel() {
	# stage 1
	if [ -d "$KERNELDIR" ]
	then
		# if the kernel directory exists
		printf "${MAGENTA}The kernel directory exists! Exiting...${NORMAL}\n"
		exit 1
	else
		# if the directory does not exist
		printf "${MAGENTA}Downloading kernel source...${NORMAL}\n"
		git clone --depth=1 https://github.com/raspberrypi/linux $KERNELDIR
		#git clone https://github.com/orangepi-xunlong/OrangePiRDA_external.git $KERNELDIR
	fi
}

downloadBootFiles() {
	# stage 1
	if [ -d "$BOOTFSDIR" ]
	then
		# if the bootfs directory exists
		printf "${MAGENTA}The bootfs directory exists! Exiting...${NORMAL}\n"
		exit 1
	else
		# if the directory does not exist
		printf "${MAGENTA}Creating bootfs directory...${NORMAL}\n"
		mkdir -p $BOOTFSDIR
		printf "${MAGENTA}Copy boot files...${NORMAL}\n"
		cp ~/rpi_boot_files.tar.gz $BOOTFSDIR
		printf "${RED}Extracting boot files...${NORMAL}\n"
		tar xzf ~/rpi_boot_files.tar.gz -C $BOOTFSDIR/
	fi
}

downloadRootFS() {
	# stage 1
	printf "${RED}Starting debootstrap...${NORMAL}\n"
	echo $pass | sudo -S debootstrap --arch=armel --foreign bullseye $ROOTFSDIR
	echo $pass | sudo -S cp /usr/bin/qemu-arm-static $ROOTFSDIR/usr/bin/
	echo $pass | sudo -S chroot $ROOTFSDIR /usr/bin/qemu-arm-static /bin/bash -c "/debootstrap/debootstrap --second-stage"
	printf "${RED}Installing packages...${NORMAL}\n"
	echo $pass | sudo -S chroot $ROOTFSDIR /usr/bin/qemu-arm-static /bin/bash -c "apt install -y wpasupplicant net-tools aptitude ca-certificates crda fake-hwclock gnupg man-db manpages ntp usb-modeswitch ssh wget xz-utils locales"
}


createConfigTXT() {
	# stage 2
	printf "${RED}Creating config.txt in bootfs...${NORMAL}\n"
	cat << EOF >> $BOOTFSDIR/config.txt
	kernel=zImage
	enable_uart=1
	device_tree=bcm2835-rpi-zero-w.dtb
	dtoverlay=disable-bt
EOF
}

createCmdLineTXT() {
	# stage 2
	printf "${RED}Creating cmdline.txt in rootfs...${NORMAL}\n"
	cat << EOF >> $BOOTFSDIR/cmdline.txt
	console=tty1 console=serial0,115200 root=/dev/mmcblk0p2 rootfstype=ext4 rootwait
EOF
}

kernelBuild() {
	# stage 2
	printf "${RED}Building kernel...${NORMAL}\n"
	cd $KERNELDIR
	KERNEL=kernel
	make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- bcmrpi_defconfig
	make -j12 ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- zImage modules dtbs
}

copyKernelFiles() {
	# stage 2
	printf "${CYAN}Copiing kernel files to boot dir...${NORMAL}\n"
	mkdir -p $BOOTFSDIR/overlays
	cp $KERNELDIR/arch/arm/boot/zImage $BOOTFSDIR/
	cp $KERNELDIR/arch/arm/boot/dts/bcm2835-rpi-zero-w.dtb $BOOTFSDIR/	
	cp $KERNELDIR/arch/arm/boot/dts/overlays/disable-bt.dtbo $BOOTFSDIR/overlays
}


installModules() {
	# stage 2
	printf "${RED}Installing kernel modules...${NORMAL}\n"
	# install modules
	cd $KERNELDIR
	echo $pass | sudo -S env PATH=$PATH make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- INSTALL_MOD_PATH=$ROOTFSDIR modules_install
}



addFilesToRootFS() {
	# stage 2
	printf "${RED}Adding files and parameters to rootfs directory...${NORMAL}\n"
	mkdir -p $ROOTFSDIR/proc
	mkdir -p $ROOTFSDIR/sys
	mkdir -p $ROOTFSDIR/dev
	mkdir -p $ROOTFSDIR/etc
	printf "${RED}Setting up root password...${NORMAL}\n"
	echo $pass | sudo -S chroot $ROOTFSDIR /usr/bin/qemu-arm-static /bin/bash -c "echo -e \"1234\n1234\" | passwd"
	echo $pass | sudo -S bash -c 'printf "ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev\nupdate_config=1\ncountry=HU\n\nnetwork={\n\t	ssid="Bubb_L"\n\t
	psk"augusztus"\n\t	key_mgmt=WPA-PSK\n}\n" > $ROOTFS/etc/wpa_supplicant/wpa_supplicant.conf'
	echo $pass | sudo -S bash -c 'printf "deb http://deb.debian.org/debian bullseye main non-free" > $ROOTFSDIR/etc/apt/sources.list'
	
		
}

compressImage() {
	printf "${RED}Compressing the built system...${NORMAL}\n"
	echo $pass | sudo -S tar czf $ROOTDIR/rpiimage.tar.gz $BOOTFSDIR/ $ROOTFSDIR/
}


#printf "${GREEN}RPI linux has been built.${NORMAL}\n"
#printf "\n"
#printf "${RED}Do not forget to prepare the SD card by execute createFS.sh, then start copyImage.sh to get the compressed folders on the host.${NORMAL}\n"


firstStage() {
	# first stage
	downloadKernel
	downloadBootFiles
	downloadRootFS
	
}

secondStage() {
	# second stage
	#kernelBuild
	#copyKernelFiles
	#installModules
	#createConfigTXT
	#createCmdLineTXT
	addFilesToRootFS
	compressImage
}

#firstStage
secondStage
