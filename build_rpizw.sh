#!/bin/bash
# boot partition 32MB, vfat
# root partition 1GB, ext4


source general.sh

installPackagesOnHost() {
	echo $pass | sudo -S apt install -y libssl-dev build-essential gcc bison bc gcc-arm-linux-gnueabi mc git debootstrap qemu-system-arm qemu-user-static
	echo $pass | sudo -S apt autoremove -y
}



downloadKernel() {
	# stage 1
	if [ -d "$KERNELDIR" ]
	then
		# if the kernel directory exists
		printf "${RED}[ The kernel directory exists! Skipping... ]${NORMAL}\n"
		# permanently stays in - Exit 1
	else
		# if the directory does not exist
		printf "${RED}[ Downloading kernel source... ]${NORMAL}\n"
		mkdir -p $ROOTDIR
		tar xzf ~/linux.tar.gz -C $ROOTDIR
		#git clone --depth=1 https://github.com/raspberrypi/linux $KERNELDIR
	fi
}

downloadBootFiles() {
	# stage 1
	if [ -d "$BOOTFSDIR" ]
	then
		# if the bootfs directory exists
		printf "${RED}[ The bootfs directory exists! Skipping... ]${NORMAL}\n"
		# permanently stays in Exit 1
	else
		# if the directory does not exist
		printf "${RED}[ Creating bootfs directory... ]${NORMAL}\n"
		mkdir -p $BOOTFSDIR
		printf "${RED}[ Copy boot files... ]${NORMAL}\n"
		cp ~/rpi_boot_files.tar.gz $BOOTFSDIR
		printf "${RED}[ Extracting boot files... ]${NORMAL}\n"
		tar xzf ~/rpi_boot_files.tar.gz -C $BOOTFSDIR/
	fi
}

downloadRootFS() {
	# stage 1
	if [ -d "$ROOTFSDIR" ]
	then
		printf "${RED}[ The rootfs directory exists! Deleting... ]${NORMAL}\n"
		echo $pass | sudo -S rm -rf $ROOTFSDIR
	fi
	printf "${RED}[ Starting debootstrap... ]${NORMAL}\n"
	export http_proxy=http://127.0.0.1:8000
	echo $pass | sudo -S debootstrap --arch=armel --components main,non-free --foreign bullseye $ROOTFSDIR http://127.0.0.1:9999/debian
	echo $pass | sudo -S cp /usr/bin/qemu-arm-static $ROOTFSDIR/usr/bin/
	echo $pass | sudo -S chroot $ROOTFSDIR /usr/bin/qemu-arm-static /bin/bash -c "/debootstrap/debootstrap --second-stage"
	printf "${RED}[ Installing locales... ]${NORMAL}\n"
	echo $pass | sudo -S chroot $ROOTFSDIR /usr/bin/qemu-arm-static /bin/bash -c "apt install -y locales"
	printf "${RED}[ Setting up locales... ]${NORMAL}\n"
	echo $pass | sudo -S chroot $ROOTFSDIR /usr/bin/qemu-arm-static /bin/bash -c 'echo "en_US.UTF-8 UTF-8" > /etc/locale.gen'
	echo $pass | sudo -S chroot $ROOTFSDIR /usr/bin/qemu-arm-static /bin/bash -c 'printf "LC_CTYPE=\"en_US.UTF-8\"" > /etc/default/locale'
	echo $pass | sudo -S chroot $ROOTFSDIR /usr/bin/qemu-arm-static /bin/bash -c 'LANG="en_US.UTF-8"'
	echo $pass | sudo -S chroot $ROOTFSDIR /usr/bin/qemu-arm-static /bin/bash -c 'locale-gen'
	echo $pass | sudo -S chroot $ROOTFSDIR /usr/bin/qemu-arm-static /bin/bash -c 'export LC_ALL="en_US.UTF-8"'

	printf "${RED}[ Disabling cert checking temporally... ]${NORMAL}\n"
	echo $pass | sudo -S chroot $ROOTFSDIR /usr/bin/qemu-arm-static /bin/bash -c "echo 'Acquire::https::deb.debian.org::Verify-Peer "false";' > ${ROOTFSDIR}/etc/apt/apt.conf.d/99debianorg-cert"
	printf "${RED}[ Creating sources.list... ]${NORMAL}\n"
	echo $pass | sudo -S bash -c 'printf "deb http://127.0.0.1:9999/debian bullseye main non-free" > ${ROOTFSDIR}/etc/apt/sources.list'
	printf "${RED}[ Installing software-properites-common...${NORMAL}\n"
	echo $pass | sudo -S chroot $ROOTFSDIR /usr/bin/qemu-arm-static /bin/bash -c "apt install -y software-properties-common"
	#printf "${RED}Adding non-free repository...${NORMAL}\n"
	#echo $pass | sudo -S chroot $ROOTFSDIR /usr/bin/qemu-arm-static /bin/bash -c "apt-add-repository non-free"
	printf "${RED}[ Updating packages... ]${NORMAL}\n"
	echo $pass | sudo -S chroot $ROOTFSDIR /usr/bin/qemu-arm-static /bin/bash -c "apt update"
	printf "${RED}[ Installing packages... ]${NORMAL}\n"
	# removed firmware-brcm80211, internal wifi
	echo $pass | sudo -S chroot $ROOTFSDIR /usr/bin/qemu-arm-static /bin/bash -c "DEBIAN_FRONTEND=noninteractive apt install -y wireless-tools sudo mc keyboard-configuration console-setup wpasupplicant net-tools aptitude ca-certificates crda fake-hwclock gnupg man-db manpages ntp usb-modeswitch ssh wget xz-utils locales firmware-realtek"
	#printf "${RED}Adding non-free...${NORMAL}\n"
	#echo $pass | sudo -S chroot $ROOTFSDIR /usr/bin/qemu-arm-static /bin/bash -c 'rm /etc/apt/sources.list'
	#echo $pass | sudo -S chroot rpi/rootfs /usr/bin/qemu-arm-static /bin/bash -c 'printf "deb http://127.0.0.1:9999/debian bullseye main non-free" > $ROOTFSDIR/etc/apt/sources.list'
	#printf "${RED}Updating packages...${NORMAL}\n"
	#echo $pass | sudo -S chroot $ROOTFSDIR /usr/bin/qemu-arm-static /bin/bash -c "apt update"
	#printf "${RED}Installing firmware-brcm80211...${NORMAL}\n"
	#echo $pass | sudo -S chroot $ROOTFSDIR /usr/bin/qemu-arm-static /bin/bash -c "apt install -y firmware-brcm80211"
}


createConfigTXT() {
	# stage 2
	printf "${RED}[ Creating config.txt in bootfs... ]${NORMAL}\n"
	cat << EOF >> $BOOTFSDIR/config.txt
	kernel=zImage
	enable_uart=1
	device_tree=bcm2835-rpi-zero-w.dtb
	#disabled internal wifi and bt
	dtoverlay=pi3-disable-bt
	dtoverlay=pi3-disable-wifi
	hdmi_force_hotplug=1
	hdmi_cvt=800 600 60 1 0 0 0
	hdmi_group=2
	hdmi_mode=87
EOF
}

createCmdLineTXT() {
	# stage 2
	printf "${RED}[ Creating cmdline.txt in rootfs... ]${NORMAL}\n"
	cat << EOF >> $BOOTFSDIR/cmdline.txt
	console=tty1 console=serial0,115200 root=/dev/mmcblk0p2 rootfstype=ext4 rootwait net.ifnames=0
EOF
}



kernelBuild() {
	# stage 2
	printf "${RED}[ Building kernel... ]${NORMAL}\n"
	cd $KERNELDIR
	KERNEL=kernel
	make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- bcmrpi_defconfig
	scripts/config --enable CONFIG_USB_OTG --disable USB_OTG_FSM --disable USB_ZERO_HNPTEST
	make -j4 ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- zImage modules dtbs
}

kernelRebuild() {
	# stage 2
	printf "${RED}[ Rebuilding kernel... ]${NORMAL}\n"
	cd $KERNELDIR
	KERNEL=kernel
	make clean
	make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- bcmrpi_defconfig
	scripts/config --enable CONFIG_USB_OTG --disable USB_OTG_FSM --disable USB_ZERO_HNPTEST
	make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- menuconfig
	make -j4 ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- zImage modules dtbs
	copyKernelFiles
	installModules
}

copyKernelFiles() {
	# stage 2
	printf "${RED}[ Copiing kernel files to boot dir... ]${NORMAL}\n"
	mkdir -p $BOOTFSDIR/overlays
	cp $KERNELDIR/arch/arm/boot/zImage $BOOTFSDIR/
	cp $KERNELDIR/arch/arm/boot/dts/bcm2835-rpi-zero-w.dtb $BOOTFSDIR/	
	cp $KERNELDIR/arch/arm/boot/dts/overlays/disable-bt.dtbo $BOOTFSDIR/overlays
}


installModules() {
	# stage 2
	printf "${RED}[ Installing kernel modules... ]${NORMAL}\n"
	# install modules
	cd $KERNELDIR
	echo $pass | sudo -S env PATH=$PATH make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- INSTALL_MOD_PATH=$ROOTFSDIR modules_install
}



addFilesToRootFS() {
	# stage 2
	printf "${RED}[ Adding files and parameters to rootfs directory... ]${NORMAL}\n"
	mkdir -p $ROOTFSDIR/proc
	mkdir -p $ROOTFSDIR/sys
	mkdir -p $ROOTFSDIR/dev
	mkdir -p $ROOTFSDIR/etc
	printf "${RED}[ Setting up root password... ]${NORMAL}\n"
	echo $pass | sudo -S chroot $ROOTFSDIR /usr/bin/qemu-arm-static /bin/bash -c "echo -e \"1234\n1234\" | passwd"
	printf "${RED}[ Creating wpa_supplicant config... ]${NORMAL}\n"
	echo $pass | sudo -S chroot $ROOTFSDIR /usr/bin/qemu-arm-static /bin/bash -c 'printf "ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev\nupdate_config=1\ncountry=HU\nnetwork={\nssid=Bubb_L\npsk augusztus\nkey_mgmt=WPA-PSK\n}\n" > /etc/wpa_supplicant/wpa_supplicant.conf'
	printf "${RED}[ Creating fstab... ]${NORMAL}\n"
	echo $pass | sudo -S chroot $ROOTFSDIR /usr/bin/qemu-arm-static /bin/bash -c 'printf "# <file system>\t<dir>\t<type>\t<options>\t<dump>\t<pass>\n/dev/mmcblk0p1\t/boot\tvfat\tdefaults\t0\t2\n/dev/mmcblk0p2\t/\text4\tdefaults,noatime\t0\t1\n" > /etc/fstab'
    printf "${RED}[ Creating interfaces... ]${NORMAL}\n"
    echo $pass | sudo -S chroot $ROOTFSDIR /usr/bin/qemu-arm-static /bin/bash -c 'printf "auto wlan0\niface wlan0 inet dhcp\nwpa-ssid Bubb_L\nwpa-psk augusztus\n" > /etc/network/interfaces.d/wlan'

	
		
}

compressImage() {
	printf "${RED}[ Compressing the built system... ]${NORMAL}\n"
	echo $pass | sudo -S tar czf $ROOTDIR/rpiimage.tar.gz $BOOTFSDIR/ $ROOTFSDIR/
}


#printf "${GREEN}RPI linux has been built.${NORMAL}\n"
#printf "\n"
#printf "${RED}Do not forget to prepare the SD card by execute createFS.sh, then start copyImage.sh to get the compressed folders on the host.${NORMAL}\n"


firstStage() {
	# first stage
	SECONDS=0
	installPackagesOnHost
	downloadKernel
	downloadBootFiles
	downloadRootFS
	printf "${LIME_YELLOW}[ First Stage running time was ${SECONDS} seconds. ]${NORMAL}\n"
}

secondStage() {
	# second stage
	SECONDS=0
	kernelBuild
	copyKernelFiles
	installModules
	createConfigTXT
	createCmdLineTXT
	addFilesToRootFS
	compressImage
	printf "${LIME_YELLOW}[ Second Stage running time was ${SECONDS} seconds. ]${NORMAL}\n"
}

packToImage() {
		printf "${RED}[ Creating emtpy image... ]${NORMAL}\n"
		sudo dd if=/dev/zero of=image.img bs=1M count=1024
		LOOP=$(sudo losetup -f --show image.img)
        MAPPER="/dev/mapper/"$(echo ${LOOP} | sed 's/\/dev\///')
		printf "${RED}[ LOOP and MAPPER node parameters are ${LOOP} and ${MAPPER} ]${NORMAL}\n"
        printf "${RED}[ Creating partitions in the image file... ]${NORMAL}\n"
        echo -e "o\nn\np\n1\n\n+64M\na\nt\nb\nn\np\n2\n\n\np\nw" | sudo fdisk ${LOOP}
        printf "${RED}[ Setting up nodes... ]${NORMAL}\n"
		sudo kpartx -av ${LOOP}
        printf "${RED}[ Formatting the boot partition... ]${NORMAL}\n"
		sudo mkfs.vfat ${MAPPER}p1
        printf "${RED}[ Formatting the root partition... ]${NORMAL}\n"
		sudo mkfs.ext3 ${MAPPER}p2
        printf "${RED}[ Cleaning up the temp folder... ]${NORMAL}\n"
		if [ -d tmp ]; then
                rm -rf tmp/
        fi
        mkdir -p tmp/boot
        mkdir -p tmp/root
		printf "${RED}[ Mounting the loop nodes... ]${NORMAL}\n"
        sudo mount ${MAPPER}p1 tmp/boot
        sudo mount ${MAPPER}p2 tmp/root
		printf "${RED}[ Copiing boot directory... ]${NORMAL}\n"
        sudo cp -r ~/rpi0wbuilder/rpi/bootfs/* tmp/boot
		printf "${RED}[ Copiing root directory... ]${NORMAL}\n"
		sudo cp -r ~/rpi0wbuilder/rpi/rootfs/* tmp/root
        printf "${RED}[ Unmounting loop nodes... ]${NORMAL}\n"
		sync
		sudo kpartx -d ${LOOP}
        sudo losetup -d ${LOOP}
		sync
		printf "${RED}[ Unmounting temp directory... ]${NORMAL}\n"
		sudo umount tmp/boot
        sudo umount tmp/root
		printf "${LIME_YELLOW}[ Image file created. ]${NORMAL}\n"
	
}

print_usage() {
	cat << EOF
	Usage: $0 <options>
		-h show help
		-f first stage
		-s second stage
		-c compress the built directory
		-r clean and rebuild kernel with menuconfig
		-a add files to root FS
		.p create image
EOF
}

if [[ $# = 0 ]]; then
	print_usage
	exit 1
fi

while getopts hfscrap options; do
	case $options in
		h)
			print_usage
			exit 1
			;;
		f)
			firstStage
			;;
		s)
			secondStage
			;;
		c)
			compressImage
			;;
		r)
			kernelRebuild
			;;
		a)
			addFilesToRootFS
			;;
		p)
			packToImage
			;;
		*)
			 printf "${RED}[ Unknown parameter added ]${NORMAL}\n"
			 exit 1
		esac
done
			


