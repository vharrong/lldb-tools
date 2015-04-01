#!/bin/bash -ex
# This script creates an qemu ubuntu image for a specific ubuntu release and arch
# it also creates a qemu binary that can run it
# if you're already created the image, you can use this script to launch it

# Usage:
# ./mk-ubuntu-img.sh <ubuntu-release> <ubuntu-arch>

# Tested configurations:
# ./mk-ubuntu-img.sh trusty arm64
# ./mk-ubuntu-img.sh trusty armhf
# ./mk-ubuntu-img.sh precise armel

# Script dependencies:
# sudo apt-get install debootstrap qemu-utils qemu

# Install build deps for qemu (apt-src must be enabled in sources.list)
# sudo apt-get build-dep qemu

# TODO
# build outside of source directories
# add default user to sudoers

UBUNTU_RELEASE=$1 # trusty or precise
UBUNTU_ARCH=$2 # armel (precise only), armhf or arm64
VMHOME="$HOME/vm"
NCPU=`egrep -c ^processor /proc/cpuinfo`

# passwordless ssh setup is disabled because I can't get host->guest connections working
if [ ! -f $HOME/.ssh/id_rsa.pub ]; then
  echo "Please run this command first:"
  echo "yes '' | ssh-keygen -t rsa"
fi

# configuration
if [ -z "$UBUNTU_RELEASE" ]; then
  UBUNTU_RELEASE=trusty
fi
if [ -z "$UBUNTU_ARCH" ]; then
  UBUNTU_ARCH=arm64
fi

case "$UBUNTU_RELEASE" in
  precise)
	;;
  trusty)
	;;
  *)
    echo "WARNING unknown arch: $UBUNTU_RELEASE"
esac

case "$UBUNTU_ARCH" in
  armel)
    export CROSS_COMPILE=arm-none-eabi-
    TOOLCHAIN_URL=http://releases.linaro.org/14.09/components/toolchain/binaries/gcc-linaro-arm-none-eabi-4.9-2014.09_linux.tar.xz
    LINUX_ARCH=arm
    LINUX_IMAGE=zImage
    QEMU_ARCH=arm
    DEFCONFIG=vexpress_defconfig
    CPU=cortex-a15
    if [ "$UBUNTU_RELEASE" != "precise" ]; then
      echo "armel only supported on precise"
      exit 1
    fi
    ;;
  armhf)
    export CROSS_COMPILE=arm-linux-gnueabihf-
    TOOLCHAIN_URL=http://releases.linaro.org/14.09/components/toolchain/binaries/gcc-linaro-arm-linux-gnueabihf-4.9-2014.09_linux.tar.xz
    LINUX_ARCH=arm
    LINUX_IMAGE=zImage
    QEMU_ARCH=arm
    DEFCONFIG=vexpress_defconfig
    CPU=cortex-a15
    ;;
  arm64)
    export CROSS_COMPILE=aarch64-linux-gnu-
    TOOLCHAIN_URL=http://releases.linaro.org/14.09/components/toolchain/binaries/gcc-linaro-aarch64-linux-gnu-4.9-2014.09_linux.tar.xz
    LINUX_ARCH=arm64
    LINUX_IMAGE=Image.gz
    QEMU_ARCH=aarch64
    DEFCONFIG=defconfig
    CPU=cortex-a57
    ;;
  *)
    echo "unknown arch: $UBUNTU_ARCH"
    exit 1
esac


PASSWORD=lldb4life
USER_LOGIN=linaro

# composite variables
SYS_ROOT=$UBUNTU_RELEASE-$UBUNTU_ARCH
WORK_DIR=$VMHOME/$SYS_ROOT-work
IMG_FILE=$SYS_ROOT.img
TOOLCHAIN_DIR=$WORK_DIR/toolchain
export PATH=$TOOLCHAIN_DIR/bin:$PATH

# clean up any tmp folders
mkdir -p $WORK_DIR
cd $WORK_DIR
sudo rm -rf $WORK_DIR/tmp $WORK_DIR/tmp.img || true

function build_qemu {
  if [ -d $WORK_DIR/qemu ]; then
    # already built
    return
  fi

  cd $WORK_DIR
  git clone git://git.qemu.org/qemu.git tmp && cd tmp
  ./configure --target-list=$QEMU_ARCH-softmmu
  make -j$NCPU

  cd $WORK_DIR
  mv tmp qemu
}

function download_packages {
  if [ -d $WORK_DIR/$SYS_ROOT-clean/ ]; then
    # already built
    return
  fi

  cd $WORK_DIR

  sudo mkdir tmp
  sudo qemu-debootstrap --arch=$UBUNTU_ARCH $UBUNTU_RELEASE tmp/
  echo "deb http://ports.ubuntu.com/ubuntu-ports $UBUNTU_RELEASE main restricted universe" > sources.list
  echo "deb-src http://ports.ubuntu.com/ubuntu-ports $UBUNTU_RELEASE main restricted universe" >> sources.list
  sudo mv sources.list tmp/etc/apt/
  sudo chroot tmp /usr/bin/apt-get -y install openssh-server
  sudo mv tmp $SYS_ROOT-clean
}

function build_sysroot {
  cd $WORK_DIR
  if [ -d $SYS_ROOT ]; then
    return
  fi

  # prepare the system image
  sudo mkdir tmp
  sudo cp -a $SYS_ROOT-clean/. tmp

  sudo sed s/tty1/ttyAMA0/g < tmp/etc/init/tty1.conf > ttyAMA0.conf
  sudo mv ttyAMA0.conf tmp/etc/init/
  touch interfaces
  sudo cat tmp/etc/network/interfaces >> interfaces
  echo "auto eth0" >> interfaces
  echo "iface eth0 inet dhcp" >> interfaces
  sudo mv interfaces tmp/etc/network/interfaces
  sudo chroot tmp useradd $USER_LOGIN -m -s /bin/bash

  # enable passwordless ssh to this guest
  sudo mkdir tmp/home/$USER_LOGIN/.ssh
  sudo cp $HOME/.ssh/id_rsa.pub tmp/home/$USER_LOGIN/.ssh/authorized_keys
  sudo chroot tmp chown -R $USER_LOGIN:$USER_LOGIN /home/$USER_LOGIN/.ssh/

  # set passwords
  echo root:$PASSWORD | sudo chroot tmp chpasswd
  echo $USER_LOGIN:$PASSWORD | sudo chroot tmp chpasswd

  echo $SYS_ROOT > hostname
  sudo mv hostname tmp/etc/hostname
  cp tmp/etc/hosts .
  echo "127.0.1.1   $SYS_ROOT" >> hosts
  sudo mv hosts tmp/etc/hosts

  sudo mv tmp $SYS_ROOT
}

function build_image {
  cd $WORK_DIR/
  if [ -f $IMG_FILE ]; then
    return
  fi

  dd if=/dev/zero of=tmp.img bs=1M count=2048
  yes y | mkfs.ext4 -b 4096 tmp.img

  sudo mkdir -p /mnt/$SYS_ROOT
  sudo mount -o loop tmp.img /mnt/$SYS_ROOT
  sudo cp -a $SYS_ROOT/. /mnt/$SYS_ROOT
  sudo umount /mnt/$SYS_ROOT

  mv tmp.img $IMG_FILE
}

function download_toolchain {
  cd $WORK_DIR
  if [ -d toolchain ]; then
    return
  fi

  wget $TOOLCHAIN_URL -O tmp.img
  mkdir tmp
  tar -C tmp --strip-components=1 -xf tmp.img

  mv tmp toolchain
}


function build_linux {
  cd $WORK_DIR
  if [ -d linux ]; then
    return
  fi

  git clone https://github.com/torvalds/linux.git tmp
  cd tmp
  git checkout v3.19 # current stable

  export ARCH=$LINUX_ARCH
  make $DEFCONFIG
  ./scripts/config -e CONFIG_LBDAF
  ./scripts/config -e CONFIG_VIRTIO_BLK
  ./scripts/config -e CONFIG_SCSI_VIRTIO
  ./scripts/config -e CONFIG_VIRTIO_NET
  ./scripts/config -e CONFIG_VIRTIO_CONSOLE
  ./scripts/config -e CONFIG_VIRTIO
  ./scripts/config -e CONFIG_VIRTIO_BALLOON
  ./scripts/config -e CONFIG_VIRTIO_MMIO
  ./scripts/config -e CONFIG_DEVTMPFS_MOUNT
  yes '' | make oldconfig
  make -j$NCPU

  cd $WORK_DIR
  
  mv tmp linux
}

download_toolchain
build_linux
build_qemu
download_packages
build_sysroot
build_image

cd $WORK_DIR

qemu/$QEMU_ARCH-softmmu/qemu-system-$QEMU_ARCH \
  -cpu $CPU \
  -machine type=virt \
  -m 2048 \
  -kernel linux/arch/$LINUX_ARCH/boot/$LINUX_IMAGE \
  -append 'console=ttyAMA0 root=/dev/vda rw' \
  -serial mon:stdio \
  -display none \
  -drive index=0,id=rootfs,file=$IMG_FILE \
  -device virtio-blk-device,drive=rootfs \
  -netdev user,id=mynet \
  -device virtio-net-device,netdev=mynet \
  -redir tcp:2222::22

# to connect to guest from host via ssh
# ssh -p 2222 linaro@127.0.0.1


