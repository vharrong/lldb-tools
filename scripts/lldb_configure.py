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
      "--coverage", action="store_true",
      help="enable code coverage capture during exe runs. Default: no capture")
  parser.add_argument(
      "--install-dir", "-i", action="store", default="install",
      help="specify the install dir, default: install")
  parser.add_argument(
      "--release", "-r", action="store_true",
      help="enable a release build. Default: (debug)")
  parser.add_argument(
      "--release-debug", action="store_true",
      help="enable a release build with debug info. Default: (debug)")
  parser.add_argument(
      "--stock-libedit", action="store_true",
      help="use stock system libedit/libedit-dev. Default: use lldb-specific "
      "libedit")
  parser.add_argument(
      "--with-python-dir",
      action="store",
      default=os.environ.get("LLDB_PYTHON_BASE_DIR"),
      help="specify alternate python root dir")

  return parser.parse_args()


def AddFileForFindInProject(llvm_parent_dir):
  filename = os.path.join(llvm_parent_dir, "llvm", "tools", "lldb",
                          ".emacs-project")
  if os.path.exists(filename):
    os.remove(filename)
  f = open(filename, "w")
  f.write(r'(setl ffip-regexp ".*\\.\\(py\\|cpp\\|c\\|h\\)$")')
  f.write("\n")
  f.close()


def GetCxxFlags(args, libedit_include_dir):
  """Construct C++ compiler flags required for the given options.

  Args:
    args: the results from parsing the command line.

    libedit_include_dir: the location where libedit include files
      should come from when not using the stock libedit.

  Returns:
    The C++ compiler flags required for the given options.

  """
  if args.stock_libedit:
    flags = ""
  else:
    flags = "-I%s" % libedit_include_dir

  if args.coverage:
    # add code coverage flags
    flags += " -fprofile-arcs -ftest-coverage"

  if args.with_python_dir:
    flags += " -I%s" % os.path.join(
        args.with_python_dir, "include", "python2.7")

  return flags


def GetLdFlags(args, libedit_lib_dir):
  """Construct linker flags required for the given options.

  Args:
    args: the results from parsing the command line.

    libedit_lib_dir: the location where libedit lib files
      should come from when not using the stock libedit.

  Returns:
    The C++ compiler flags required for the given options.

  """
  if args.stock_libedit:
    flags = ""
  else:
    flags = "-L%s" % libedit_lib_dir

  if args.coverage:
    # add code coverage flags
    flags += " -fprofile-arcs -ftest-coverage"

  if args.with_python_dir:
    flags += " -L{} -L{}".format(
        os.path.join(args.with_python_dir, "lib"),
        os.path.join(args.with_python_dir, "lib", "python2.7", "config"))

  return flags


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
    print("Warning: libedit lib directory for platform does not exist:\n  " +
          local_libedit_lib_dir)
    print "Forcing use of stock libedit"
    args.stock_libedit = True
  else:
    # FIXME: address LD_LIBRARY_PATH analog for Windows
    if "LD_LIBRARY_PATH" in os.environ:
      os.environ["LD_LIBRARY_PATH"] = (local_libedit_lib_dir +
                                       ":" + os.environ["LD_LIBRARY_PATH"])
    else:
      os.environ["LD_LIBRARY_PATH"] = local_libedit_lib_dir

  # if code coverage is enabled, we must have debug info, either by
  # --release-debug or debug (i.e. release must not be set)
  if args.coverage and args.release:
    print("Error: code coverage requires debug info in the build.\n"
          "Choose --release-debug or exclude --release on the command line.")
    exit(1)

  # Make build directory
  os.makedirs(build_dir)

  with workingdir.WorkingDir(build_dir):

    cxx_flags = GetCxxFlags(args, local_libedit_include_dir)
    ld_flags = GetLdFlags(args, local_libedit_lib_dir)

    if args.use_cmake:
      if args.release_debug:
        build_type_name = "RelWithDebInfo"
      elif args.release:
        build_type_name = "Release"
      else:
        build_type_name = "Debug"
      config_message = "configured for cmake/ninja (%s)" % build_type_name

      command_tokens = ("cmake",
                        "-GNinja",
                        "-DCMAKE_CXX_COMPILER=g++",
                        "-DCMAKE_C_COMPILER=gcc",
                        "-DCMAKE_CXX_FLAGS=%s" % cxx_flags,
                        "-DCMAKE_SHARED_LINKER_FLAGS=%s" % ld_flags,
                        "-DCMAKE_EXE_LINKER_FLAGS=%s" % ld_flags,
                        "-DCMAKE_INSTALL_PREFIX:PATH=%s" % install_dir,
                        "-DCMAKE_BUILD_TYPE=%s" % build_type_name,
                        # Do not include this next flag if you want to see
                        # cmake maintainer-related messages.
                        "-Wno-dev",
                        os.path.join("..", "llvm"))
    else:
      command_tokens = [os.path.join("..", "llvm", "configure"),
                        "--enable-cxx11",
                        "--prefix=%s" % install_dir]

      if args.release_debug:
        command_tokens.append("--enable-optimized")
        command_tokens.append("--enable-assertions")
        # we need to add -g to tell it to include debug info in the
        # release build
        cxx_flags += " -g"
        config_message = ("configured for configure/(g)make "
                          "release,debuginfo,assertions)")
      elif args.release:
        command_tokens.append("--enable-optimized")
        command_tokens.append("--disable-assertions")
        config_message = "configured for configure/(g)make (release)"
      else:
        command_tokens.append("--disable-optimized")
        command_tokens.append("--enable-assertions")
        config_message = "configured for configure/(g)make (debug,assertions)"

      command_tokens.append("--with-extra-options=%s" % cxx_flags)
      command_tokens.append("--with-extra-ld-options=%s" % ld_flags)

    print " ".join(command_tokens)
    status = subprocess.call(command_tokens)
    if status != 0:
      print "configure command failed (see above)."
      exit(1)

    print ""
    print config_message
    if args.stock_libedit:
      print "using stock system libedit"
    else:
      print "using custom libedit ({},{})".format(
          local_libedit_include_dir, local_libedit_lib_dir)

    if args.with_python_dir:
      print "using custom python ({})".format(args.with_python_dir)
    else:
      print "using stock system python"

    print "The build directory has been set up:"
    print "cd " + build_dir


if __name__ == "__main__":
  main()
