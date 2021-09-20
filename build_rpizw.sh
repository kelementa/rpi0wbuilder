#!/bin/sh
# boot partition 32MB, vfat
# root partition 1GB, ext4

export pass=218agkaki

BLACK=$(tput setaf 0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
LIME_YELLOW=$(tput setaf 190)
POWDER_BLUE=$(tput setaf 153)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
WHITE=$(tput setaf 7)
BRIGHT=$(tput bold)
NORMAL=$(tput sgr0)
BLINK=$(tput blink)
REVERSE=$(tput smso)
UNDERLINE=$(tput smul)

prepare() {
	printf "${RED}Removing build directory...${NORMAL}\n"
	rm -rf /home/kelement/rpi
	printf "${RED}Creating build directory...${NORMAL}\n"
	mkdir -p /home/kelement/rpi
	printf "${RED}Setting up variables...${NORMAL}\n"
	export RPI_DIR=/home/kelement/rpi
	export RPI_BOOT=$RPI_DIR/boot
	export RPI_ROOT=$RPI_DIR/root
	export RPI_KERNEL=$RPI_DIR/linux
	printf "${RED}Extracting boot files...${NORMAL}\n"
	cp ~/rpi_boot_files.tar.gz $RPI_DIR
	mkdir -p $RPI_BOOT
	mkdir -p $RPI_ROOT
	tar xvzf $RPI_DIR/rpi_boot_files.tar.gz -C $RPI_BOOT/
}


kernelBuild() {
	export RPI_KERNEL=/home/kelement/rpi/linux
	git clone --depth=1 https://github.com/raspberrypi/linux $RPI_KERNEL
	cd $RPI_KERNEL
	KERNEL=kernel
	make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- bcmrpi_defconfig
	make -j4 ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- zImage modules dtbs
}

copyKernelFiles() {
printf "${RED}Copiing kernel files to boot dir...${NORMAL}\n"
export RPI_DIR=/home/kelement/rpi
export RPI_BOOT=$RPI_DIR/boot
export RPI_ROOT=$RPI_DIR/root
export RPI_KERNEL=$RPI_DIR/linux
mkdir $RPI_BOOT/overlays
cp $RPI_KERNEL/arch/arm/boot/zImage $RPI_BOOT/
cp $RPI_KERNEL/arch/arm/boot/dts/bcm2835-rpi-zero-w.dtb $RPI_BOOT/
cp $RPI_KERNEL/arch/arm/boot/dts/overlays/disable-bt.dtbo $RPI_BOOT/overlays
}

createFiles() {
export RPI_DIR=/home/kelement/rpi
export RPI_BOOT=$RPI_DIR/boot
export RPI_ROOT=$RPI_DIR/root
export RPI_KERNEL=$RPI_DIR/linux
printf "${RED}Creating config.txt...${NORMAL}\n"
cat << EOF >> $RPI_BOOT/config.txt
# Use the Linux Kernel we compiled earlier.
kernel=zImage

# Enable UART so we can use a TTL cable.
enable_uart=1

# Use the appropriate DTB for our device.
device_tree=bcm2835-rpi-zero-w.dtb

# Disable Bluetooth via device tree overlay.
# It's a complicated explanation that you
# can read about here: https://youtu.be/68jbiuf27AY?t=431
# IF YOU SKIP THIS STEP, your serial connection will not
# work correctly.
dtoverlay=disable-bt
EOF

printf "${RED}Creating cmdline.txt...${NORMAL}\n"
cat << EOF >> $RPI_BOOT/cmdline.txt
console=tty1 console=serial0,115200 root=/dev/mmcblk0p2 rootfstype=ext4 rootwait
EOF
}

installModules() {
export RPI_DIR=/home/kelement/rpi
export RPI_BOOT=$RPI_DIR/boot
export RPI_ROOT=$RPI_DIR/root
export RPI_KERNEL=$RPI_DIR/linux
printf "${RED}Installing kernel modules...${NORMAL}\n"
# install modules
cd $RPI_KERNEL
echo $pass | sudo -S env PATH=$PATH make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- INSTALL_MOD_PATH=$RPI_ROOT modules_install
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

addToRootFS() {
export RPI_DIR=/home/kelement/rpi
export RPI_BOOT=$RPI_DIR/boot
export RPI_ROOT=$RPI_DIR/root
export RPI_KERNEL=$RPI_DIR/linux
export RPI_BUSYBOX=$RPI_DIR/busybox
printf "${RED}Creating FS dirs...${NORMAL}\n"
mkdir -p $RPI_ROOT/proc
mkdir -p $RPI_ROOT/sys
mkdir -p $RPI_ROOT/dev
mkdir -p $RPI_ROOT/etc
mkdir -p $RPI_ROOT/etc/init.d
touch $RPI_ROOT/etc/init.d/rcS
chmod +x $RPI_ROOT/etc/init.d/rcS

cat << EOF >> $RPI_ROOT/etc/init.d/rcS
#!/bin/sh
mount -t proc none /proc
mount -t sysfs none /sys

echo /sbin/mdev > /proc/sys/kernel/hotplug
mdev -s
EOF
}

compressImage() {
	printf "${RED}Compressing the system...${NORMAL}\n"
	tar cvzf rpiimage.tar.gz $RPI_BOOT/ $RPI_ROOT/
}

prepare
kernelBuild
copyKernelFiles
createFiles
installModules
busyBox
addToRootFS
printf "${GREEN}RPI linux has been built.${NORMAL}\n"
printf "\n"
printf "${RED}Do not forget to prepare the SD card by execute createFS.sh, then start copyImage.sh to get the compressed folders on the host.${NORMAL}\n"

