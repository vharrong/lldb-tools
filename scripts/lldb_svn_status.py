#!/usr/bin/env python

"""Do an svn status on llvm, clang, and lldb."""


# Python built-in modules
import os


# Our modules
import lldb_utils


def main():
  llvm_parent_dir = lldb_utils.FindLLVMParentInParentChain()
  if not llvm_parent_dir:
    raise ValueError("Not in (or adjacent to) an llvm tree")

  lldb_utils.RunInDirectory(os.path.join(llvm_parent_dir, "llvm"),
                            ("svn", "status"))
  lldb_utils.RunInDirectory(os.path.join(llvm_parent_dir,
                                         "llvm", "tools", "clang"),
                            ("svn", "status"))
  lldb_utils.RunInDirectory(os.path.join(llvm_parent_dir,
                                         "llvm", "tools", "lldb"),
                            ("svn", "status"))


if __name__ == "__main__":
  main()
