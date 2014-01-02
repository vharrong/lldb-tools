#!/usr/bin/env python

"""Do a git pull on just the llvm part of the lldb sandbox.

The actual command is 'git pull origin master:master'

"""


import os

import lldb_utils


def main():
  llvm_parent_dir = lldb_utils.FindLLVMParentInParentChain()
  if not llvm_parent_dir:
    raise ValueError("Not in (or adjacent to) an llvm tree")

  if lldb_utils.GitPull(os.path.join(llvm_parent_dir, "llvm"),
                        "origin", "master:master") != 0:
    print "Error: Failed to pull llvm (see error(s) above)"


if __name__ == "__main__":
  main()
