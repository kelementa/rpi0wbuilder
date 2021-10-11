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

showColors() {
    printf "${BLACK}The color is BLACK${NORMAL}\n"
    printf "${RED}The color is RED${NORMAL}\n"
    printf "${GREEN}The color is GREEN${NORMAL}\n"
    printf "${YELLOW}The color is YELLOW${NORMAL}\n"
    printf "${LIME_YELLOW}The color is LIME_YELLOW${NORMAL}\n"
    printf "${POWDER_BLUE}The color is POWDER_BLUE${NORMAL}\n"
    printf "${BLUE}The color is BLUE${NORMAL}\n"
    printf "${MAGENTA}The color is MAGENTA${NORMAL}\n"
    printf "${CYAN}The color is CYAN${NORMAL}\n"
    printf "${WHITE}The color is WHITE${NORMAL}\n"
    printf "${BRIGHT}The color is BRIGHT${NORMAL}\n"
    printf "${NORMAL}The color is NORMAL${NORMAL}\n"
    printf "${BLINK}The color is BLINK${NORMAL}\n"
    printf "${REVERSE}The color is REVERSE${NORMAL}\n"
    printf "${UNDERLINE}The color is UNDERLINE${NORMAL}\n"
}