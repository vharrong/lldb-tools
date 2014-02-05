#!/usr/bin/env python

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


# Python built-in modules
import os
import subprocess
import sys


# Our modules
import lldb_utils
import workingdir


def AddFileForFindInProject(llvm_parent_dir):
  filename = os.path.join(llvm_parent_dir, "llvm", "tools", "lldb", ".emacs-project")
  if os.path.exists(filename):
    os.remove(filename)
  f = open(filename, "w")
  f.write(r'(setl ffip-regexp ".*\\.\\(cpp\\|c\\|h\\)$")')
  f.write("\n")
  f.close()


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

  # find the parent of the llvm directory
  llvm_parent_dir = lldb_utils.FindLLVMParentInParentChain()
  print "Found llvm parent dir: " + (llvm_parent_dir if llvm_parent_dir else "<none>")

  # Fail if no such place
  if not llvm_parent_dir:
    print "Error: No llvm directory found in parent chain."
    exit(1)

  # Do this before checking for clang so it will work even if if that fails (e.g., on a Mac)
  AddFileForFindInProject(llvm_parent_dir)

  # fail if there is a clang in the path
  clang_path = lldb_utils.FindInExecutablePath("clang")
  if clang_path:
    print "Error: 'clang' was found in PATH: " + clang_path
    print "Our lldb build setup does not support building with clang."
    print "Please remove clang from your path."
    exit(1)

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

  scripts_dir = os.path.dirname(os.path.realpath(__file__))
  lldb_dir = os.path.dirname(scripts_dir)
  local_libedit_dir = os.path.abspath(os.path.join(lldb_dir, "libedit"))
  local_libedit_include_dir = os.path.join(local_libedit_dir, "include")
  local_libedit_lib_dir = os.path.join(local_libedit_dir, lldb_utils.FullPlatformName(), "lib")

  if not os.path.exists(local_libedit_lib_dir):
    print "Error: libedit lib directory for platform does not exist:\n  " + local_libedit_lib_dir
    exit(1)

  # FIXME: Fix next line for Windows
  os.environ["LD_LIBRARY_PATH"] = local_libedit_lib_dir + ":" + os.environ["LD_LIBRARY_PATH"]

  # Make build directory
  os.makedirs(build_dir)

  with workingdir.WorkingDir(build_dir):

    command_tokens = (os.path.join("..", "llvm", "configure"),
                      "--enable-cxx11",
                      "--with-extra-options=-I%s" % local_libedit_include_dir,
                      "--with-extra-ld-options=-L%s" % local_libedit_lib_dir,
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
