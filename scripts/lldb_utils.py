"""Utility methods for building and maintaining lldb.

FindParentInParentChain -- Find a directory in the parent chain.
FindLLVMParentInParentChain -- Find 'llvm' in the parent chain.
FindInExecutablePath -- Find a program in the executable path.
PrintRemoveTreeCommandForPath -- print a command to remove a path.
GitClone -- Call 'git clone' in a given directory.

"""


import calendar
import os
import platform
import re
import subprocess
import sys
import time
import workingdir


def FindParentInParentChain(item):
  """Find the closet path with the given name in the parent directory hierarchy.

  Args:
    item: relative path to be found (may contain a directory path (a/b/c)).

  Returns:
    The full path of found directory, or None if no such path was found.

  Raises:
    ValueError:  if given an absolute path.

  """
  if os.path.isabs(item):
    raise ValueError("FindParentInParentChain takes relative path")
  trydir = os.getcwd()
  while True:
    trypath = os.path.join(trydir, item)
    if os.path.exists(trypath):
      return trydir

    # loop to the parent directory, stopping once we've evaluated at the root.
    lastdir = trydir
    trydir = os.path.dirname(lastdir)
    if os.path.samefile(lastdir, trydir):
      return None


def _FindGitOrSvnControlledDirInParentChain(dir_name):
  """Find VC-controlled dir_name within parent dir chain.

  Args:

    dir_name: the directory name to find in the current directory or
      one of the parent directories up through the root of the current
      directory's file system. The directory parent chain is first
      checked for a dir_name child that is a git-controlled directory.
      If that fails to find dir_name within the parent chain, it
      checks to see if a subversion-controlled directory is present.

  Returns:
    The parent directory of the git/svn-controlled directory specified
    in the parent chain, or None when the directory specified is not
    found.
  """

  # first try assuming git repos
  parent = FindParentInParentChain(os.path.join(dir_name, ".git"))
  if parent:
    return parent

  # next try assuming svn
  return FindParentInParentChain(os.path.join(dir_name, ".svn"))


def FindLLVMParentInParentChain():
  """Find the llvm tree above us or at the same level."""
  return _FindGitOrSvnControlledDirInParentChain("llvm")


def FindInExecutablePath(prog):
  """Find the given program in the executable path.

  Args:
    prog: The program to find.

  Returns:
    The full pathname or None if prog not in path.

  """
  user_path = os.environ["PATH"]       # TODO(spucci) fix? on Windows...
  for pathdir in user_path.split(os.pathsep):
    pathdir = pathdir.rstrip("/")
    pathdir = pathdir.rstrip("\\")  # Windows
    try_path = os.path.join(pathdir, prog)
    if os.path.exists(try_path):
      return try_path
  return None


def PrintRemoveTreeCommandForPath(path):
  """Print the command to remove the given path.

  Useful for cut-and-paste from error message.

  Args:
    path: The root of the tree to remove.

  """
  print "You can remove this path with:"
  print "rm -rf " + path    # TODO(spucci): Fix Windows


def SSOCookieExpired():
  """Return whether ~/.sso/cookie says it's expired.

  If the cookie file is missing, we presume it's expired.

  Returns:
    True iff the cookie is missing or has expired.

  """
  cookie_dir = os.path.join(os.environ["HOME"], ".sso")
  cookie_path = os.path.join(cookie_dir, "cookie")
  if not os.path.exists(cookie_path):
    return True
  cookie_string = open(cookie_path).read()

  match = re.search("expires=(\\d+),", cookie_string)
  if match:
    cookie_date = int(match.group(1))
    now_date = calendar.timegm(time.gmtime())
    return now_date > cookie_date
  else:
    print "Warning: no cookie expiration in file " + cookie_path
    return False


def RequireProdaccess():
  """Exit with an error message if no prodaccess.

  Uses prodcertstatus and parses output.

  """
  if sys.platform.startswith("linux"):
    try:
      prodstatus = subprocess.check_output("prodcertstatus",
                                           stderr=subprocess.STDOUT)
    except subprocess.CalledProcessError as e:
      prodstatus = e.output
      if not prodstatus.startswith("LOAS cert expires in "):
        prodstatus = prodstatus.rstrip("\n")
        print "prodstatus is '" + prodstatus + "'"
        print "Do you need to run prodaccess?"
        exit(1)
  else:
    if SSOCookieExpired():
      print "SSO login expired!  To fix, run:"
      print "git credential-sso login"
      exit(1)


def GitClone(in_dir, remote_path):
  """Run "git clone" in a given directory.

  Will leave the cwd untouched on exit.

  Args:
    in_dir: (local) directory in which to run the 'git clone'
    remote_path: the git remote path to clone

  Returns:
    The 'git' command status.

  Raises:
    TypeError: if there are missing arguments

  """

  if not remote_path:
    raise TypeError("GitClone requires (local) directory and remote path")

  # Go to directory, saving old path
  with workingdir.WorkingDir(in_dir):
    print "cd " + in_dir

    command_tokens = ("git", "clone", remote_path)
    print " ".join(command_tokens)
    status = subprocess.call(command_tokens)
    if status != 0:
      print "git command failed (see above)."

  return status


def GitPull(in_dir, remote="origin", branch_mapping="master:master"):
  """Run "git pull" in a given directory.

  Will leave the cwd untouched on exit.

  Args:
    in_dir: the (local) directory in which to run the 'git ull'
    remote: (optional) the remote to pull from (defaults to: "origin")
    branch_mapping: (optional) branch mapping (defaults to: "master:master")

  Returns:
    The 'git' command status.

  Raises:
    TypeError: if there are missing arguments

  """

  if not in_dir:
    raise TypeError("GitPull requires (local) directory")

  # Go to directory, saving old path
  with workingdir.WorkingDir(in_dir):
    print "cd " + in_dir

    command_tokens = ("git", "pull", remote, branch_mapping)
    print " ".join(command_tokens)
    status = subprocess.call(command_tokens)
    if status != 0:
      print "git command failed (see above)."

  return status


def FullPlatformName():
  """Return the full platform name, e.g., linux-x86_64."""

  if sys.platform.startswith("linux"):
    return "linux-" + platform.processor()
  else:
    raise TypeError("Unsupported architecture: " + sys.platform)
