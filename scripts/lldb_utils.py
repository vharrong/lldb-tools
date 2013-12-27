"""Utility methods for building and maintaining lldb."""


import os


# Find the closet path with the given name in the parent directory hierarchy.
# 'item' must be relative path, and may contain a directory path (a/b/c)
def FindParentInParentChain(item):
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


# Find the llvm tree above us or at the same level
def FindLLVMParentInParentChain():
  return FindParentInParentChain(os.path.join("llvm", ".git"))


# Find the given program in the executable path.
# Returns the full pathname or None if not in path.
def FindInExecutablePath(prog):
  user_path = os.environ["PATH"]       # TODO(spucci) fix? on Windows...
  for pathdir in user_path.split(os.pathsep):
    pathdir = pathdir.rstrip("/")
    pathdir = pathdir.rstrip("\\")  # Windows
    try_path = os.path.join(pathdir, prog)
    if os.path.exists(try_path):
      return try_path
  return None


# Print the command to remove the given path.
# Useful for cut-and-paste from error message.
def PrintRemoveTreeCommandForPath(path):
  print "You can remove this path with:"
  print "rm -rf " + path    # TODO(spucci): Fix Windows
