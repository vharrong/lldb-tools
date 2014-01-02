#!/usr/bin/env python

"""Do a git pull on just the clang part of the lldb sandbox.

The actual command is 'git pull origin master:master'

"""


import os

import lldb_utils


def main():
  llvm_parent_dir = lldb_utils.FindParentInParentChain(
      os.path.join("llvm", "tools", "clang", ".git"))
  if not llvm_parent_dir:
    raise ValueError("Not in (or adjacent to) an llvm tree")

  if lldb_utils.GitPull(os.path.join(llvm_parent_dir, "llvm", "tools", "clang"),
                        "origin", "master:master") != 0:
    print "Error: Failed to pull clang (see error(s) above)"


if __name__ == "__main__":
  main()
