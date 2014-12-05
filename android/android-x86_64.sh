#!/bin/sh

BUILD_DIR=x86_64-android-4.9
TOOLCHAIN_DIR=/home/achien/SDK/ndk-x86_64-4.9
TBLGEN_DIR=/home/achien/Projects/build_clang/bin 

rm -rf $BUILD_DIR
./lldb-tools/scripts/lldb_configure.py -c -n -target android -arch x86-64-android -toolchain $TOOLCHAIN_DIR -tblgen_dir $TBLGEN_DIR -b $BUILD_DIR
if [ $? = "0" ]; then
  echo "Config done."
  cd $BUILD_DIR
  ninja -v
else
  echo "Config failed."
fi
