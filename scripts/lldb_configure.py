#!/usr/bin/python2.7

"""Run configure for the lldb project.

Usage: configure_lldb.py [BUILD_DIR [INSTALL_DIR]]
   BUILD_DIR defaults to 'build'.
   INSTALL_DIR defaults to 'install'.

 Runs, in <llvm>/../BUILD_DIR:
 <llvm>/configure --prefix=<llvm>/../INSTALL_DIR.
 where <llvm> is an llvm directory that is git-controlled.

 This script checks to make sure that the system does
 not have a clang defined in the path.  Currently this will
 break our build on Goobuntu 12.04, where we assume we
 build with gcc 4.8+.

"""


import os
import subprocess
import sys


import lldb_utils
import workingdir


def main():
  # determine build directory
  if len(sys.argv) >= 2:
    build_relative_dir = sys.argv[1]
  else:
    build_relative_dir = "build"
  # print "Using build dir: " + build_relative_dir

  # determine install directory
  if len(sys.argv) >= 3:
    install_relative_dir = sys.argv[2]
  else:
    install_relative_dir = "install"
  # print "Using install dir: " + install_relative_dir

  # fail if there is a clang in the path
  clang_path = lldb_utils.FindInExecutablePath("clang")
  if clang_path:
    print "Error: 'clang' was found in PATH: " + clang_path
    print "Our lldb build setup does not support building with clang."
    print "Please remove clang from your path."
    exit(1)

  # find the parent of the llvm directory
  llvm_parent_dir = lldb_utils.FindLLVMParentInParentChain()
  # print "Found llvm parent dir: " +
  #     (llvm_parent_dir if llvm_parent_dir else "<none>")

  build_dir = os.path.join(llvm_parent_dir, build_relative_dir)
  install_dir = os.path.join(llvm_parent_dir, install_relative_dir)

  # fail if the build directory already exists
  if os.path.exists(build_dir):
    print "Error: build directory must not already exist: " + build_dir
    print "Please delete before re-running."
    lldb_utils.PrintRemoveTreeCommandForPath(build_dir)
    exit(1)

  # fail if the install directory already exists
  if os.path.exists(install_dir):
    print "Error: install directory must not already exist: " + install_dir
    print "Please delete before re-running."
    lldb_utils.PrintRemoveTreeCommandForPath(install_dir)
    exit(1)

  # Make build directory
  os.makedirs(build_dir)

  with workingdir.WorkingDir(build_dir):

    command_tokens = (os.path.join("..", "llvm", "configure"),
                      "--enable-cx11",
                      "--prefix=%s" % install_dir)
    print " ".join(command_tokens)
    status = subprocess.call(command_tokens)
    if status != 0:
      print "configure command failed (see above)."
      exit(1)

    print ""
    print "The build directory has been set up:"
    print "cd " + build_dir

if __name__ == "__main__":
  main()
