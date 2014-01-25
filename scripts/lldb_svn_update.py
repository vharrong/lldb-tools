#!/usr/bin/env python

"""Do an svn update on llvm, clang, and lldb."""


# Python built-in modules
import os


# Our modules
import lldb_utils


def main():
  llvm_parent_dir = lldb_utils.FindLLVMParentInParentChain()
  if not llvm_parent_dir:
    raise ValueError("Not in (or adjacent to) an llvm tree")

  lldb_utils.RunInDirectory(os.path.join(llvm_parent_dir, "llvm"), ("svn", "update"))
  lldb_utils.RunInDirectory(os.path.join(llvm_parent_dir, "llvm", "tools", "clang"), ("svn", "update"))
  lldb_utils.RunInDirectory(os.path.join(llvm_parent_dir, "llvm", "tools", "lldb"), ("svn", "update"))


if __name__ == "__main__":
  main()
