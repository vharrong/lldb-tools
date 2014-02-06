#!/usr/bin/env python

"""Run configure for the lldb project.

 See lldb_configure.py -h for usage.

 Configures lldb to be build with either configure/(g)make (the
 default) or cmake/ninja (with an appropriate flag).

 This script checks to make sure that the system does
 not have a clang defined in the path.  Currently this will
 break our build on Goobuntu 12.04, where we assume we
 build with gcc 4.8+.

"""


# Python built-in modules
import argparse
import os
import subprocess


# Our modules
import lldb_utils
import workingdir


def ParseCommandLine():
  """Parse the command line and return a parser results object.

  Parse the command line arguments, returning a parser object
  suitable to control command execution decisions.

  Returns:
    A parser results object containing the results of parsing the command line.
  """
  parser = argparse.ArgumentParser(
      description="Configure lldb build environment.")

  parser.add_argument(
      "--cmake", "-c", action="store_true", dest="use_cmake",
      help="set configure system to cmake (default: configure)")
  parser.add_argument(
      "--build-dir", "-b", action="store", default="build",
      help="specify the build dir, default: build")
  parser.add_argument(
      "--install-dir", "-i", action="store", default="install",
      help="specify the install dir, default: install")

  return parser.parse_args()


def AddFileForFindInProject(llvm_parent_dir):
  filename = os.path.join(llvm_parent_dir, "llvm", "tools", "lldb",
                          ".emacs-project")
  if os.path.exists(filename):
    os.remove(filename)
  f = open(filename, "w")
  f.write(r'(setl ffip-regexp ".*\\.\\(cpp\\|c\\|h\\)$")')
  f.write("\n")
  f.close()


def main():
  args = ParseCommandLine()

  # find the parent of the llvm directory
  llvm_parent_dir = lldb_utils.FindLLVMParentInParentChain()
  print "Found llvm parent dir: " + (llvm_parent_dir
                                     if llvm_parent_dir else "<none>")

  # Fail if no such place
  if not llvm_parent_dir:
    print "Error: No llvm directory found in parent chain."
    exit(1)

  # Do this before checking for clang so it will work even if if that
  # fails (e.g., on a Mac)
  AddFileForFindInProject(llvm_parent_dir)

  # fail if there is a clang in the path
  clang_path = lldb_utils.FindInExecutablePath("clang")
  if clang_path:
    print "Error: 'clang' was found in PATH: " + clang_path
    print "Our lldb build setup does not support building with clang."
    print "Please remove clang from your path."
    exit(1)

  build_dir = os.path.join(llvm_parent_dir, args.build_dir)
  install_dir = os.path.join(llvm_parent_dir, args.install_dir)

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
  local_libedit_lib_dir = os.path.join(local_libedit_dir,
                                       lldb_utils.FullPlatformName(), "lib")

  if not os.path.exists(local_libedit_lib_dir):
    print("Error: libedit lib directory for platform does not exist:\n  " +
          local_libedit_lib_dir)
    exit(1)

  # FIXME: Fix next line for Windows
  os.environ["LD_LIBRARY_PATH"] = (local_libedit_lib_dir +
                                   ":" + os.environ["LD_LIBRARY_PATH"])

  # Make build directory
  os.makedirs(build_dir)

  with workingdir.WorkingDir(build_dir):

    if args.use_cmake:
      command_tokens = ("cmake",
                        "-GNinja",
                        "-DCMAKE_CXX_COMPILER=g++",
                        "-DCMAKE_C_COMPILER=gcc",
                        "-DLLVM_ENABLE_CXX11=ON",
                        "-DCMAKE_CXX_FLAGS=-I%s" % local_libedit_include_dir,
                        "-DCMAKE_EXE_LINKER_FLAGS=-L%s" % local_libedit_lib_dir,
                        "-DCMAKE_INSTALL_PREFIX:PATH=%s" % install_dir,
                        os.path.join("..", "llvm"))
    else:
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
