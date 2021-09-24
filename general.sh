#!/bin/bash

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

export pass=218agkaki

TOPDIR=`pwd`
ROOTDIR=${TOPDIR}/rpi
KERNELDIR=${ROOTDIR}/linux
BOOTFSDIR=${ROOTDIR}/bootfs
ROOTFSDIR=${ROOTDIR}/rootfs

echo $pass | sudo -S apt install -y build-essential gcc bison bc gcc-arm-linux-gnueabi mc git debootstrap qemu-system-arm qemu-user-static
