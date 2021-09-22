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
		tar xvzf ~/rpi_boot_files.tar.gz -C $BOOTFSDIR/
	fi
}

downloadRootFS() {
	# stage 1
	echo $pass | sudo -S debootstrap --arch=armel --foreign bullseye $ROOTFSDIR
	echo $pass | sudo -S cp /usr/bin/qemu-arm-static $ROOTFSDIR/usr/bin/
	echo $pass | sudo -S chroot $ROOTFSDIR /usr/bin/qemu-arm-static /bin/bash -c "/debootstrap/debootstrap --second-stage"
}


createConfigTXT() {
	# stage 2
	printf "${RED}Creating config.txt...${NORMAL}\n"
	cat << EOF >> $BOOTFSDIR/config.txt
	kernel=zImage
	enable_uart=1
	device_tree=bcm2835-rpi-zero-w.dtb
	dtoverlay=disable-bt
EOF
}

createCmdLineTXT() {
	# stage 2
	printf "${RED}Creating cmdline.txt...${NORMAL}\n"
	cat << EOF >> $BOOTFSDIR/cmdline.txt
	console=tty1 console=serial0,115200 root=/dev/mmcblk0p2 rootfstype=ext4 rootwait
EOF
}

kernelBuild() {
	# stage 2
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

busyBox() {
export RPI_DIR=/home/kelement/rpi
export RPI_BOOT=$RPI_DIR/boot
export RPI_ROOT=$RPI_DIR/root
export RPI_KERNEL=$RPI_DIR/linux
export RPI_BUSYBOX=$RPI_DIR/busybox
printf "${RED}Downloading busybox...${NORMAL}\n"
git clone git://busybox.net/busybox.git --branch=1_33_0 --depth=1 $RPI_BUSYBOX
cd $RPI_BUSYBOX
# Settings -> Build static binary (no shared libraries) -> enable
# Settings -> Cross compiler prefix -> arm-linux-gnueabihf-
# Settings -> Destination path for ‘make install’ -> $RPI_ROOT
printf "${RED}Set default config...${NORMAL}\n"
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- defconfig
sed -i 's/CONFIG_PREFIX=".\/_install"/CONFIG_PREFIX="\/home\/kelement\/rpi\/root"/g' .config
sed -i 's/CONFIG_CROSS_COMPILER_PREFIX=""/CONFIG_CROSS_COMPILER_PREFIX="arm-linux-gnueabi-"/g' .config
sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/g' .config
printf "${RED}Building...${NORMAL}\n"
make -j4 ARCH=arm CROSS_COMPILE=arm-linux-gnueabi-
printf "${RED}Install busybox...${NORMAL}\n"
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- install
}

addFilesToRootFS() {
	# stage 2
	printf "${RED}Adding files to FS directory...${NORMAL}\n"
	mkdir -p $ROOTFSDIR/proc
	mkdir -p $ROOTFSDIR/sys
	mkdir -p $ROOTFSDIR/dev
	mkdir -p $ROOTFSDIR/etc
	#mkdir -p $ROOTFSDIR/etc/init.d
	#echo $pass | sudo -S touch $ROOTFSDIR/etc/init.d/rcS
	#echo $pass | sudo -S printf "#!/bin/sh\nmount -t proc none /proc\nmount-t sysfs none /sys\necho /sbin/mdev > /proc/sys/kernel/hotplug\nmdev -s" >>$ROOTFSDIR/etc/init.d/rcS
	#echo $pass | sudo -S chmod +x $ROOTFSDIR/etc/init.d/rcS
	
}

compressImage() {
	printf "${RED}Compressing the system...${NORMAL}\n"
	echo $pass | sudo -S tar cvzf $ROOTDIR/rpiimage.tar.gz $BOOTFSDIR/ $ROOTFSDIR/
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
	kernelBuild
	copyKernelFiles
	installModules
	createConfigTXT
	createCmdLineTXT
	addFilesToRootFS
	compressImage
}

firstStage