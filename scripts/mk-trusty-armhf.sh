#!/bin/bash -ex

# TODO
# remove exports?
# build outside of source directories

if [ ! -f $HOME/.ssh/id_rsa.pub ]; then
  echo "Please run this command first:"
  echo "yes '' | ssh-keygen -t rsa"
fi

# configuration
export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabihf-
ARCHEX=armhf
RELEASE=trusty
QEMU_TARGET=arm-softmmu
PASSWORD=lldb4life
USER_LOGIN=linaro

# composite variables
SYS_ROOT=$RELEASE-$ARCHEX
WORK_DIR=$HOME/$SYS_ROOT-work
IMG_FILE=$SYS_ROOT.img
TOOLCHAIN_DIR=$WORK_DIR/toolchain
export PATH=$TOOLCHAIN_DIR/bin:$PATH

# clean up any tmp folders
mkdir -p $WORK_DIR
cd $WORK_DIR
sudo rm -rf $WORK_DIR/tmp tmp.img || true

function build_qemu {
  if [ -d $WORK_DIR/qemu ]; then
    # already built
    return
  fi

  cd $WORK_DIR
  git clone git://git.qemu.org/qemu.git tmp && cd tmp
  ./configure --target-list=$QEMU_TARGET
  make -j32

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
  sudo qemu-debootstrap --arch=$ARCHEX trusty tmp/
  echo "deb http://ports.ubuntu.com/ubuntu-ports trusty main restricted universe" > sources.list
  echo "deb-src http://ports.ubuntu.com/ubuntu-ports trusty main restricted universe" >> sources.list
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
  sudo cp $HOME/.ssh/id_rsa.pub tmp/home/$USER_LOGIN/.ssh/
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

  wget http://releases.linaro.org/14.09/components/toolchain/binaries/gcc-linaro-arm-linux-gnueabihf-4.9-2014.09_linux.tar.xz -O tmp.img
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
  #git checkout v3.7 # or some other version

  make vexpress_defconfig
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
  make -j32

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

qemu/$QEMU_TARGET/qemu-system-$ARCH \
  -cpu cortex-a15 \
  -machine type=virt \
  -m 2048 \
  -kernel linux/arch/$ARCH/boot/zImage \
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


