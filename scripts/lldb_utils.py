"""Utility methods for building and maintaining lldb.

FindParentInParentChain -- Find a directory in the parent chain.
FindLLVMParentInParentChain -- Find 'llvm' in the parent chain.
FindInExecutablePath -- Find a program in the executable path.
PrintRemoveTreeCommandForPath -- print a command to remove a path.
GitClone -- Call 'git clone' in a given directory.

"""


import os
import subprocess


def FindParentInParentChain(item):
  """Find the closet path with the given name in the parent directory hierarchy.

  Args:
    item: relative path to be found (may contain a directory path (a/b/c)).

  Returns:
    The full path of found directory, or None if no such path was found.

  Raises:
    ValueError:  if given an absolute path.

  """
  if item.startswith("/"):
    raise ValueError("FindParentInParentChain takes relative path")
  # TODO(spucci): (maybe) add a check for Windows absolute paths as above
  trydir = os.getcwd()
  while True:
    trypath = os.path.join(trydir, item)
    if os.path.exists(trypath):
      return trydir
    if "/" in trydir:
      (trydir, unused_a, unused_b) = trydir.rpartition("/")
    elif "\\" in trydir:  # Windows
      (trydir, unused_a, unused_b) = trydir.rpartition("\\")
    else:
      return None


def FindLLVMParentInParentChain():
  """Find the llvm tree above us or at the same level."""
  return FindParentInParentChain(os.path.join("llvm", ".git"))


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
  save_wd = os.getcwd()
  print "cd " + in_dir
  os.chdir(in_dir)

  command_tokens = ("git", "clone", remote_path)
  print " ".join(command_tokens)
  status = subprocess.call(command_tokens)
  if status != 0:
    print "git command failed (see above)."

  print "cd " + save_wd
  os.chdir(save_wd)

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
  save_wd = os.getcwd()
  print "cd " + in_dir
  os.chdir(in_dir)

  command_tokens = ("git", "pull", remote, branch_mapping)
  print " ".join(command_tokens)
  status = subprocess.call(command_tokens)
  if status != 0:
    print "git command failed (see above)."

  print "cd " + save_wd
  os.chdir(save_wd)

  return status
