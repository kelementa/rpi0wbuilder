#!/bin/bash
source general.sh

printf "${RED}Building kernel...${NORMAL}\n"
	cd $KERNELDIR
	KERNEL=kernel
	make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- bcmrpi_defconfig
    make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- menuconfig
	#make -j12 ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- zImage modules dtbs